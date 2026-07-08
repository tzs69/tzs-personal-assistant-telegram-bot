import json
import logging
import os
import boto3
from pydantic import ValidationError
from datetime import datetime, timezone
from schemas import TelegramMessageUserInput, TelegramMessageAgentResponse, InputValidationErrorResponse

AGENT_RUNTIME_ARN = os.environ.get("AGENT_RUNTIME_ARN")
TELE_PID=int(os.environ.get("TELE_PID"))
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
        logger.warning(f"Invalid Lambda event format, expected dict, got {type(event)}")
        return "", 200 
    
    logger.info(f"REQUEST PAYLOAD:\n{json.dumps(event)}")

    user_input_validated: TelegramMessageUserInput = _validate_input(input=event, logger=logger)
    if isinstance(user_input_validated, InputValidationErrorResponse):
        if user_input_validated.sender_id and user_input_validated.error_msg:
            return {
                "method": "sendMessage",
                "chat_id": user_input_validated.sender_id,
                "text": user_input_validated.error_msg
            }
        elif not user_input_validated.sender_id and user_input_validated.error_msg=="Edited message event":
            return "", 200
        else:
            return "", 400
    sender_id = user_input_validated.sender_id

    try:
        # Pass validated input to agent runtime for answer generation
        response = client.invoke_agent_runtime(
            agentRuntimeArn=AGENT_RUNTIME_ARN,
            payload=user_input_validated.model_dump_json(),
            contentType="application/json",
            accept="application/json",
            qualifier="DEFAULT",
        )
    except Exception:
        logger.exception("AgentCore invocation failed")
        return {
            "method": "sendMessage",
            "chat_id": sender_id,
            "text": "AgentCore invocation failed. Message was not processed."
        }
    
    response_body = response['response'].read().decode("utf-8")
    agent_response = TelegramMessageAgentResponse.model_validate_json(response_body)
    
    return {
        "method": "sendMessage",
        "chat_id": sender_id,
        "text": agent_response.text,
    }




def _validate_input(
    input: dict, 
    logger: logging.Logger
) -> TelegramMessageUserInput | InputValidationErrorResponse:
    try:
        body_raw = input["body"]
        try:
            body_parsed = json.loads(body_raw)
        except Exception:
            logger.exception("INPUT VALIDATION ERROR: request body is not valid JSON")
            return InputValidationErrorResponse()
        if len(body_parsed) == 0:
            logger.warning("INPUT VALIDATION ERROR: empty request body")
            return InputValidationErrorResponse()
    except Exception:
        logger.exception("INPUT VALIDATION ERROR: missing or malformed Lambda event body")
        return InputValidationErrorResponse()
    
    # Skip edit message events to only trigger answer generation on new messages("message")
    if "edited_message" in body_parsed.keys():
        logger.info("Edited message event received, skipping.")
        return InputValidationErrorResponse(error_msg="Edited message event")
    
    message = body_parsed.get("message", {})
    if not isinstance(message, dict):
        logger.warning("INPUT VALIDATION ERROR: Telegram message payload is malformed")
        return InputValidationErrorResponse()
    if len(message) == 0:
        logger.warning("INPUT VALIDATION ERROR: Telegram message payload is empty")
        return InputValidationErrorResponse()
    
    try:
        from_id = message.get("from", {}).get("id")
        chat_id = message.get("chat", {}).get("id")
        if not from_id or not chat_id:
            logger.warning("INPUT VALIDATION ERROR: Telegram from.id or chat.id is missing")
            return InputValidationErrorResponse()
    except Exception:
        logger.exception("INPUT VALIDATION ERROR: failed to read Telegram from.id or chat.id")
        return InputValidationErrorResponse()
    
    # PID validation: both from_id and chat_id should == my own tele PID 
    # (private bot, cannot be added to grps)
    if from_id != TELE_PID or chat_id != TELE_PID or from_id != chat_id:
        logger.warning(f"INPUT VALIDATION ERROR: Telegram sender/chat id {chat_id} does not match allowed personal id {TELE_PID}")
        return InputValidationErrorResponse()
    sender_id = str(chat_id)

    text = message.get("text", "")
    if not isinstance(text, str):
        logger.warning("INPUT VALIDATION ERROR: Telegram message text is malformed")
        return InputValidationErrorResponse()
    if len(text) == 0:
        logger.warning("INPUT VALIDATION ERROR: Telegram message text is empty")
        return InputValidationErrorResponse()
    
    # Get msg date (fallback to container runtime date (in same timezone utc) if date is empty or malformed)
    date = message.get("date")
    if date and isinstance(date, int):
        date = datetime.fromtimestamp(date, tz=timezone.utc).strftime('%d%m%Y')
    else:
        date = datetime.now(timezone.utc).strftime('%d%m%Y')

    username = message.get("from", {}).get("username") or message.get("chat", {}).get("username")
    logger.info(f"Valid message payload received: {json.dumps({ 
        "username": username,
        "chat_id": str(chat_id),
        "message": text,
        "date": date
    })}")

    try:
        out = TelegramMessageUserInput(
            username=username,
            sender_id=sender_id,
            text=text,
            date=date
        )    
        return out
    except ValidationError:
        return InputValidationErrorResponse(
            sender_id = sender_id,
            error_msg = "INPUT VALIDATION ERROR: validated Telegram input failed schema validation"
        )
