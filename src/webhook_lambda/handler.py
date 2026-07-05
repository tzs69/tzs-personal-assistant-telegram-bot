import json
import logging
import os
import boto3
from typing import Dict
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
        logger.exception(f"Invalid request payload format, expected dict, got {type(event)}")
        return "", 200 
    
    logger.info(f"REQUEST PAYLOAD:\n{json.dumps(event)}")

    user_input_validated: TelegramMessageUserInput = _validate_input(input=event, logger=logger)
    sender_id = user_input_validated.sender_id

    try:
        # Pass validated input to agent runtime for answer generation
        response = client.invoke_agent_runtime(
            agentRuntimeArn=AGENT_RUNTIME_ARN,
            payload=user_input_validated.model_dump_json(),
            qualifier="DEFAULT"
        )
    except Exception:
        logger.exception("AgentCore invocation failed")
        return {
            "method": "sendMessage",
            "chat_id": sender_id,
            "text": "Agentcore invocation failed, Message failed to process."
        }
    
    response_body = response['response'].read().decode("utf-8")
    agent_response = TelegramMessageAgentResponse.model_validate_json(response_body)
    
    return {
        "method": "sendMessage",
        "chat_id": sender_id,
        "text": agent_response.text,
    }


def _validate_input(input: dict, logger: logging.Logger) -> TelegramMessageAgentResponse:
    try:
        body_raw = input["body"]
        try:
            body_parsed = json.loads(body_raw)
        except Exception:
            logger.exception("INPUT VALIDATION ERROR: raw request body breaks JSON syntax rules")
            return "", 400
        if len(body_parsed) == 0:
            logger.exception("INPUT VALIDATION ERROR: empty request body")
            return "", 400
    except Exception:
        logger.exception("INPUT VALIDATION ERROR: Malformed event body")
        return "", 400 
    
    # Skip edit message events to only trigger answer generation on new messages("message")
    if "edited_message" in body_parsed.keys():
        logger.info("Edited message event received, skipping.")
        return "", 200
    
    message = body_parsed.get("message", {})
    if not isinstance(message, dict):
        logger.exception("INPUT VALIDATION ERROR: Malformed telegram message payload")
        return "", 400
    if len(message) == 0:
        logger.exception("INPUT VALIDATION ERROR: Empty telegram message payload dict")
        return "", 400
    
    try:
        from_id = message.get("from", {}).get("id")
        chat_id = message.get("chat", {}).get("id")
        if not from_id or not chat_id:
            logger.exception("INPUT VALIDATION ERROR: from_id / chat_id missing from telegram message payload")
            return "", 400
    except Exception:
        logger.exception("INPUT VALIDATION ERROR: failed to obtain message's from_id / chat_id")
        return "", 400
    
    # PID validation: both from_id and chat_id should == my own tele PID 
    # (private bot, cannot be added to grps)
    if from_id != TELE_PID or chat_id != TELE_PID or from_id != chat_id:
        logger.exception(f"INPUT VALIDATION ERROR: from_id: {chat_id} does not match personal id: {TELE_PID}")
        return "", 400

    text = message.get("text", "")
    if not isinstance(text, str):
        logger.exception("INPUT VALIDATION ERROR: Malformed telegram message text")
        return "", 400
    if len(text) == 0:
        logger.exception("INPUT VALIDATION ERROR: Empty telegram message text")
        return "", 400
        
    date = message.get("date")
    username = message.get("from", {}).get("username") or message.get("chat", {}).get("username")
    logger.info(f"Valid message payload received: {json.dumps({ 
        "username": username,
        "chat_id": chat_id,
        "message": text,
        "date": date
    })}")

    return TelegramMessageUserInput(
        username=username,
        sender_id=from_id,
        text=text,
        date=date
    )    
