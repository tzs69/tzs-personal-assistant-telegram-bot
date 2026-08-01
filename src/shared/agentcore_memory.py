import logging
from typing import Any, Dict, List
from bedrock_agentcore.memory import MemoryClient
from schemas import TelegramMessageUserInput, TelegramMessageAgentResponse


class MemoryManagementService:
    def __init__(self, memory_id: str, region: str, logger: logging.Logger):
        self.memory_id = memory_id
        self.__memory_client: MemoryClient = MemoryClient(region_name=region)
        self.logger = logger

    def retrieve_relevant_memories(
        self,
        sender_id: str,
        query: str,
        top_k: int = 5
    ) -> str:
        """
        Perform semantic retrieval of extracted long-term memory records.

        Sample retrieval response obj:
        [ 
            { 
                "content": { ... },
                "createdAt": number,
                "memoryRecordId": "string",
                "memoryStrategyId": "string",
                "metadata": { 
                    "string" : { ... }
                },
                "namespaces": [ "string" ],
                "score": number
            }, 
            { 
            ...
        ]
        """
        if not isinstance(sender_id, str) or len(sender_id) == 0:
            self.logger.warning("Invalid sender_id, long-term memory retrieval aborted")
            return ""
        if not isinstance(query, str) or len(query.strip()) == 0:
            self.logger.warning("Invalid query, long-term memory retrieval aborted")
            return ""
        if not isinstance(top_k, int) or isinstance(top_k, bool) or top_k <= 0:
            self.logger.warning("Invalid top_k, long-term memory retrieval aborted")
            return ""

        try:
            retrieve_response: List[Dict[str, Any]] = self.__memory_client.retrieve_memories(
                memory_id=self.memory_id,
                namespace_path=f"/actor/{sender_id}",
                query=query,
                top_k=top_k,
            )
        except Exception as e:
            self.logger.exception(f"{type(e).__name__}: Failed to retrieve relevant memories.")
            return ""

        if not isinstance(retrieve_response, list):
            self.logger.error(f"Invalid memory retrieval response format, expected list, got {type(retrieve_response)}")
            return ""
        
        if len(retrieve_response) == 0:
            self.logger.info("Memory retrieval returned empty results list")
            return ""
        
        relevant_memories = []
        for memory_record in retrieve_response:
            if not isinstance(memory_record, dict):
                continue

            content = memory_record.get("content", {})
            if not isinstance(content, dict):
                continue

            text = content.get("text", "")
            if isinstance(text, str) and len(text) > 0:
                relevant_memories.append(text)

        if len(relevant_memories) == 0:
            self.logger.warning("Memory retrieval response contained no usable content fields")
            return ""
        
        relevant_memories_ranked = [
            f"{i}) {memory_content}"
            for i, memory_content in enumerate(relevant_memories, start=1)
        ]
        return "\n".join(relevant_memories_ranked)


    def fetch_short_term_memories(self, sender_id: str, max_turns: int) -> List[Dict[str, Any]]:
        """
        Sample ``get_last_k_turns`` response object:
        [
            [
                {
                    "content": {"text": "question 1 bla bla..."},
                    "role": "USER"
                },
                {
                    "content": {"text": "answer 1 bla bla..."},
                    "role": "ASSISTANT"
                }
            ],
            [
                {
                    "content": {"text": "question 2 bla bla..."},
                    "role": "USER"
                },
                {
                    "content": {"text": "answer 2 bla bla..."},
                    "role": "ASSISTANT"
                }
            ]
        ]

        Each outer-list item represents one conversation turn. A turn begins
        with a user message and may contain one or more assistant messages.

        Returns messages in the shape expected by Strands, ordered from oldest
        to newest:
        [
            {
                "role": "user",
                "content": [{"text": "question 1 bla bla..."}]
            },
            {
                "role": "assistant",
                "content": [{"text": "answer 1 bla bla..."}]
            }
        ]
        """

        if not isinstance(sender_id, str) or len(sender_id) <= 0:
            self.logger.warning("Invalid sender_id (must be a non-empty string), short-term memory fetch aborted")
            return []
        if not isinstance(max_turns, int) or max_turns <= 0:
            self.logger.warning("Invalid max_turns (must be an int > 0), short-term memory fetch aborted")
            return []
        try:
            last_k_turns_response: List[List[Dict[str, Any]]] = self.__memory_client.get_last_k_turns(
                memory_id = self.memory_id,
                actor_id = sender_id,
                session_id = self._get_session_id(sender_id),
                k = max_turns
            )
        except Exception as e:
            self.logger.exception(f"{type(e).__name__}: Failed to retrieve fetch short-term memories.")
            return []

        if not isinstance(last_k_turns_response, list):
            self.logger.error(f"Invalid short-term memory fetch response format, expected list, got {type(last_k_turns_response)}")
            return []

        if len(last_k_turns_response) == 0:
            self.logger.info("Short-term memory fetch returned empty results list")
            return []

        last_k_turns = self._to_strands_messages(last_k_turns_response)

        if len(last_k_turns) == 0:
            self.logger.warning("Short-term memory fetch response contained no nonempty convo turns")
            return []

        return last_k_turns


    def add_memory_event(
        self,
        user_query: TelegramMessageUserInput,
        agent_response: TelegramMessageAgentResponse
    ) -> None:
        """
        if event_timestamp is None:
                event_timestamp = datetime.utcnow()

            params = {
                "memoryId": memory_id,
                "actorId": actor_id,
                "sessionId": session_id,
                "eventTimestamp": event_timestamp,
                "payload": payload,
                "clientToken": str(uuid.uuid4()),
            }
            response = memory_client.create_event(**params)

            event = response["event"]
            logger.info("Created event: %s", event["eventId"])
        """
        # Build memory payload
        messages = [
            (user_query.text, 'USER'),
            (agent_response.text, 'ASSISTANT')
        ]
        try:
            self.__memory_client.create_event(
                memory_id = self.memory_id,
                actor_id = str(user_query.sender_id),
                session_id = self._get_session_id(user_query.sender_id),
                messages = messages
            )
        except Exception as e:
            self.logger.exception(f"{type(e).__name__}: Failed to create agent memory event")


    def _get_session_id(self, sender_id: str):
        return f"telegram_{sender_id}"


    def _to_strands_messages(
        self,
        turns: List[List[Dict[str, Any]]]
    ) -> List[Dict[str, Any]]:
        messages: List[Dict[str, Any]] = []

        # AgentCore returns the latest turn first; Strands expects chronological history (reverse
        for turn in reversed(turns):
            if not isinstance(turn, list):
                continue

            for item in turn:
                if not isinstance(item, dict):
                    continue

                role = item.get("role", "")
                content = item.get("content", {})
                if not isinstance(role, str) or not isinstance(content, dict):
                    continue

                text = content.get("text", "")
                role = role.lower()
                if role not in {"user", "assistant"} or not isinstance(text, str) or not text:
                    continue

                messages.append({
                    "role": role,
                    "content": [{"text": text}]
                })

        return messages
