import os
import json
import logging
from typing import Dict, List
from bedrock_agentcore import BedrockAgentCoreApp
from strands import Agent
from strands.agent import AgentResult
from schemas import TelegramMessageUserInput, TelegramMessageAgentResponse
from agentcore_memory import MemoryManagementService


logging.basicConfig(level=logging.INFO, force=True)
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
app = BedrockAgentCoreApp()

_SRC_CODE_SHA = os.environ.get("_CODE_SHA") # For update triggering in terraform script; not for use in py file
AGENT_RUNTIME_MODEL_ID = os.environ.get("AGENT_RUNTIME_MODEL_ID")
AGENT_MEMORY_ID = os.environ.get("AGENT_MEMORY_ID")
AGENT_MEMORY_REGION = os.environ.get("AGENT_MEMORY_REGION", "us-east-1")
SYSTEM_PROMPT = '''
You are a general knowledge question-answer telegram bot.
You will receive general knowledge user queries, and your job is to 
answer them in a clear and concise manner (Not more than 100 words).
'''

agent = Agent(
    model=AGENT_RUNTIME_MODEL_ID,
    system_prompt=SYSTEM_PROMPT
)

memory = MemoryManagementService(
    memory_id=AGENT_MEMORY_ID,
    region=AGENT_MEMORY_REGION,
    logger=logger
)

@app.entrypoint
def invoke(payload):

    if not isinstance(payload, dict):
        return _raise_error_message_generic(
            error=TypeError,
            error_msg=f"Invalid AgentCore invocation payload format, expected dict, got {type(payload)}",
            logger=logger
        )

    
    sender_id = payload.get("sender_id")
    text = payload.get("text", "")
    if not sender_id:
        return _raise_error_message_generic(
            error=ValueError,
            error_msg="sender_id field is missing from AgentCore invocation payload",
            logger=logger
        )
    if not text:
        return _raise_error_message_generic(
            error=ValueError,
            error_msg="text field is missing from AgentCore invocation payload",
            logger=logger
        )

    logger.info(f"Valid AgentCore invocation payload received from webhook Lambda:\n{json.dumps(payload)}")
    user_message = TelegramMessageUserInput.model_validate(payload)

    try:
        # Fetch past convo chunks relevant to query and append to system prompt dynamically
        try:
            memories_fetched = ""
            past_memories = memory.retrieve_relevant_memories(user_query=user_message)

            if isinstance(past_memories, str) and len(past_memories) > 0:
                memories_fetched = f"""
                \nThe below list contains relevant past conversational context chunks sorted in
                descending order of semantic similarity with regards to the user's query:\n
                {past_memories}
                """
                logger.info("Agent memory chunks successfully retrieved and dynamically added to system prompt")
        except Exception:
            logger.exception("Failed to retrieve relevant memories")
        
        if len(memories_fetched) > 0:
            agent.system_prompt += memories_fetched

        try:
            response: AgentResult = agent(user_message.text)
        finally:
            # Reset to base even if agent invocation fails after memory injection.
            if memories_fetched:
                agent.system_prompt = SYSTEM_PROMPT
                logger.info("System prompt reverted to base")

    except Exception as e:
        return _raise_error_message_generic(
            error=e,
            error_msg="Agent runtime invocation failed.",
            logger=logger
        )

    # Log raw agent response
    debug_payload = response.to_dict()
    logger.info(f"Raw agent response:\n{json.dumps(debug_payload)}")
    
    # Parse agent response to obtain message string
    agent_message_content_wrapper = response.message.get("content", [])
    error_response = _agent_response_fails_validation(agent_message_content_wrapper)
    if error_response and isinstance(error_response, TelegramMessageAgentResponse):
        return error_response.model_dump()

    agent_message_content = agent_message_content_wrapper[0].get("text", "")
    error_response = _agent_response_fails_validation(agent_message_content)
    if error_response and isinstance(error_response, TelegramMessageAgentResponse):
        return error_response.model_dump()
    
    agent_response = TelegramMessageAgentResponse(
        text = agent_message_content,
        error = None
    )

    memory.add_memory_event(user_query=user_message, agent_response=agent_response)

    return agent_response.model_dump()


if __name__ == "__main__":
    app.run()


def _agent_response_fails_validation(response: List | Dict) -> TelegramMessageAgentResponse | None:
    if len(response) == 0:
        response_validation_error_message = "Agent runtime returned an empty response."
        logger.error(response_validation_error_message)
        return TelegramMessageAgentResponse(
            text = response_validation_error_message,
            error = ValueError
        )
    return None

def _raise_error_message_generic(
    error: BaseException, 
    error_msg: str, 
    logger: logging.Logger
) -> TelegramMessageAgentResponse:
    if isinstance(error, BaseException):
        logger.exception(error_msg)
    else:
        logger.error(error_msg)
    return TelegramMessageAgentResponse(
        text = error_msg,
        error = error
    ).model_dump()
