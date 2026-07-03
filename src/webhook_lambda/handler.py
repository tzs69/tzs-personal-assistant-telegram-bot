import json
import logging
import os
import boto3
from schemas import TelegramMessageUserInput, TelegramMessageAgentResponse

AGENT_RUNTIME_ARN = os.environ.get("AGENT_RUNTIME_ARN")
TELE_PID=int(os.environ.get("TELE_PID"))
TELE_BOT_API_KEY=os.environ.get("TELE_BOT_API_KEY")
AGENT_RUNTIME_REGION = os.environ.get("AGENT_RUNTIME_REGION", "us-east-1")

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

client = boto3.client("bedrock-agentcore", region_name=AGENT_RUNTIME_REGION)

# Temporary dummy for early stage infrastructure provision
def handler(event, context):
    '''
    '''

    # Validate and parse telegram event
    if not isinstance(event, dict):
        logger.exception(f"Invalid telegram payload format, expected dict, got {type(event)}")
    
    body = json.loads(event["body"])
    message = body.get("message")
    if not message:
        logger.exception("message field missing from raw telegram update payload")

    # PID validation: both from_id and chat_id should == my own tele PID (private bot, cannot be added to grps)
    from_id = message.get("from", {}).get("id")
    chat_id = message.get("chat", {}).get("id")
    if not from_id:
        logger.exception("from_id field missing from telegram message payload")
    elif from_id != TELE_PID:
        logger.exception(f"from_id: {chat_id} does not match personal id: {TELE_PID}")
    if not chat_id:
        logger.exception("chat_id field missing from telegram message payload")
    elif chat_id != TELE_PID:
        logger.exception(f"chat_id: {chat_id} does not match personal id: {TELE_PID}")

    text = message.get("text", "")
    if len(text) == 0:
        logger.exception("Empty message detected")

    date = message.get("date")
    logger.info(f"Message received: {json.dumps({ 
        "sender_id": from_id,
        "message": text,
        "date": date
    })}")

    username = message.get("from", {}).get("username")

    user_input_payload = TelegramMessageUserInput(
        username=username,
        sender_id=from_id,
        text=text,
        date=date
    )
    try:
        response = client.invoke_agent_runtime(
            agentRuntimeArn=AGENT_RUNTIME_ARN,
            payload=user_input_payload.model_dump_json(),
            qualifier="DEFAULT"
        )
    except Exception:
        logger.exception("AgentCore invocation failed")
        return {
            "method": "sendMessage",
            "chat_id": from_id,
            "text": "Message failed to process"
        }
    
    response_body = response['response'].read().decode("utf-8")
    agent_response = TelegramMessageAgentResponse.model_validate_json(response_body)
    
    return {
        "method": "sendMessage",
        "chat_id": from_id,
        "text": agent_response.text,
    }
