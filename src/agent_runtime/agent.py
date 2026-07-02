import os
import json
import logging
from typing import Dict, List
from bedrock_agentcore import BedrockAgentCoreApp
from strands import Agent
from schemas import TelegramMessageUserInput, TelegramMessageAgentResponse

logging.basicConfig(level=logging.INFO, force=True)
logger = logging.getLogger(__name__)
app = BedrockAgentCoreApp()

_SRC_CODE_SHA = os.environ.get("_CODE_SHA") # For update triggering in terraform script; not for use in py file
AGENT_RUNTIME_MODEL_ID = os.environ.get("AGENT_RUNTIME_MODEL_ID")
SYSTEM_PROMPT = '''
You are a general knowledge question-answer telegram bot.
You will receive general knowledge user queries, and your job is to 
answer them in a clear and concise manner (Not more than 100 words).
'''

agent = Agent(
    model=AGENT_RUNTIME_MODEL_ID,
    system_prompt=SYSTEM_PROMPT
)

@app.entrypoint
def invoke(payload):

    if not isinstance(payload, dict):
        validate_input_error_message = f"Invalid lambda payload format, expected dict, got {type(payload)}"
        logger.exception(validate_input_error_message)
        return TelegramMessageAgentResponse(
            text = validate_input_error_message,
            error = TypeError
        ).model_dump()
    
    sender_id = payload.get("sender_id")
    text = payload.get("text", "")
    if not sender_id:
        validate_input_error_message = "sender_id field missing from lambda payload"
        logger.exception(validate_input_error_message)
        return TelegramMessageAgentResponse(
            text = validate_input_error_message,
            error = ValueError
        ).model_dump()
    if not text:
        validate_input_error_message = "text field missing from lambda payload"
        logger.exception(validate_input_error_message)
        return TelegramMessageAgentResponse(
            text = validate_input_error_message,
            error = ValueError
        ).model_dump()

    print(f"Valid payload received from webhook lambda:\n{json.dumps(payload)}")
    logger.info(f"Valid payload received from webhook lambda:\n{json.dumps(payload)}")
    user_message = TelegramMessageUserInput.model_validate(payload)

    try:
        response = agent(user_message.text)
    except Exception as e:
        invocation_error_message = "Agent runtime invocation failed, exiting."
        logger.exception(invocation_error_message)
        return TelegramMessageAgentResponse(
            text = invocation_error_message,
            error = e
        ).model_dump()

    debug_payload = response.to_dict()
    print(f"{json.dumps(debug_payload)}")


    logger.info(f"{json.dumps(debug_payload)}")
    # Shld look smth like this:
    '''
JSON
{
    "type": "agent_result",
    "message": {
        "role": "assistant",
        "content": [{"text": 
            "# Healthy Lunch for Weight Management\n\nFor someone with obesity, 
            focus on:\n\n- **Lean protein**: Grilled chicken, fish, or turkey\n- 
            **Non-starchy vegetables**: Broccoli, spinach, carrots, peppers\n- 
            **Whole grains**: in moderation, brown rice or quinoa\n- **Healthy fats**: 
            Olive oil, avocado (small portions)\n\n**Example meal**: Grilled chicken 
            breast with steamed broccoli and sweet potato.\n\n**Key tips**:\n- Control 
            portions\n- Avoid fried/processed foods\n- Stay hydrated\n- Consult a 
            doctor/dietitian for personalized guidance\n\nSustainable weight loss 
            requires medical oversight and professional dietary planning."
        }]
    },
    "metadata": {
        "usage": {
        "inputTokens": 66,
        "outputTokens": 166,
        "totalTokens": 232
        },
        "metrics": {
        "latencyMs": 2449,
        "timeToFirstByteMs": 1045
        }
    },
    "stop_reason": "end_turn",
    "checkpoint": null
}
    '''

    
    agent_message_content_wrapper = response.message.get("content", [])
    error_response = _agent_response_fails_validation(agent_message_content_wrapper)
    if error_response and isinstance(error_response, TelegramMessageAgentResponse):
        return error_response.model_dump()

    agent_message_content = agent_message_content_wrapper[0].get("text", "")
    error_response = _agent_response_fails_validation(agent_message_content)
    if error_response and isinstance(error_response, TelegramMessageAgentResponse):
        return error_response.model_dump()
    
    response_wrapped = TelegramMessageAgentResponse(
        text = f"Message:\n{agent_message_content}\n\nStop reason:\n{response.stop_reason}",
        error=None
    )
    return response_wrapped.model_dump()


if __name__ == "__main__":
    app.run()


def _agent_response_fails_validation(response: List | Dict) -> TelegramMessageAgentResponse | None:
    if len(response) == 0:
        response_validation_error_message = "Agent runtime invocation returned an empty response, exiting."
        logger.exception(response_validation_error_message)
        return TelegramMessageAgentResponse(
            text = response_validation_error_message,
            error = ValueError
        )
    return None