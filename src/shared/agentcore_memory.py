import logging
from typing import Any, Dict, List
from bedrock_agentcore.memory import MemoryClient
from schemas import TelegramMessageUserInput, TelegramMessageAgentResponse


class MemoryManagementService:
    def __init__(self, memory_id: str, region: str, logger: logging.Logger):
        self.memory_id = memory_id
        self.__memory_client: MemoryClient = MemoryClient(region_name=region)
        self.logger = logger

    def retrieve_relevant_memories(self, user_query: TelegramMessageUserInput, top_k: int = 10) -> str:
        """
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
        try:
            retrieve_response: List[Dict[str, Any]] = self.__memory_client.retrieve_memories(
                memory_id=self.memory_id,
                namespace_path= f"/actor/{user_query.sender_id}",
                query = user_query.text,
                top_k = top_k,
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
        
        relevant_memories = list(filter(
            lambda memory_content: len(memory_content) > 0 ,
            list(map(
                lambda memory_record: memory_record.get("content", ""),
                retrieve_response
            ))    
        ))

        if len(relevant_memories) == 0:
            self.logger.warning("Memory retrieval response contained no usable content fields")
            return ""
        
        relevant_memories_ranked = [f"{i}) {memory_content}" for i, memory_content in enumerate(relevant_memories, start=1)]
        return "\n".join(relevant_memories_ranked)


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
                session_id = f"telegram_{user_query.sender_id}_{user_query.date}",
                messages = messages
            )
        except Exception as e:
            self.logger.exception(f"{type(e).__name__}: Failed to create agent memory event")
