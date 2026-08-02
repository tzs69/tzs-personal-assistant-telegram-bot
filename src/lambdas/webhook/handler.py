import json
import logging
import os
import boto3
from pydantic import ValidationError
from datetime import datetime, timezone
from typing import Dict
import hashlib, hmac
from schemas import TelegramMessageAgentInput, InputValidationErrorResponse, TelegramInvocationJob

SQS_QUEUE_URL=os.environ.get("SQS_QUEUE_URL")
TELE_PID=int(os.environ.get("TELE_PID"))
TELE_BOT_API_KEY=os.environ.get("TELE_BOT_API_KEY", "")

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

sqs_client = boto3.client("sqs")

def handler(event, context):

    # Validate and parse telegram event
    if not isinstance(event, dict):
        logger.warning(f"Invalid Lambda event format, expected dict, got {type(event)}")
        return {"statusCode": 200, "body": ""}

    headers = event.get("headers") or {} 
    headers = {k.lower(): v for k, v in headers.items()}
    if not verify_telegram_request(headers=headers, logger=logger):
        logger.error("Inbound request signature verification failed")
        return {"statusCode": 401, "body": ""}

    validation_result: TelegramInvocationJob | InputValidationErrorResponse = _validate_input(
        input=event,
        logger=logger
    )

    if isinstance(validation_result, InputValidationErrorResponse):
        if validation_result.sender_id and validation_result.error_msg:
            return {
                "method": "sendMessage",
                "chat_id": validation_result.sender_id,
                "text": validation_result.error_msg
            }
        else:
            return {"statusCode": 200, "body": ""}

    invocation_job = validation_result
    sender_id = invocation_job.agent_input.sender_id

    try:
        # Enqueue built job payload to sqs
        sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=invocation_job.model_dump_json(),
            MessageGroupId=sender_id,
            MessageDeduplicationId=f"telegram-update-{invocation_job.update_id}"
        )
        return {"statusCode": 200, "body": ""}
    except Exception:
        logger.exception(f"Failed to enqueue Telegram update {invocation_job.update_id} to the invoker queue")
        return {"statusCode": 500, "body": ""}
    

def verify_telegram_request(
    headers: Dict,
    logger: logging.Logger
):
    telegram_signature = headers.get("x-telegram-bot-api-secret-token", "")
    if not telegram_signature:
        logger.warning("Telegram signature missing in lambda event payload")
        return False
    signing_secret = hashlib.sha256(TELE_BOT_API_KEY.encode()).hexdigest()
    valid = hmac.compare_digest(signing_secret, telegram_signature)
    if not valid:
        logger.warning("Signature mismatch")
    return valid


def _validate_input(
    input: Dict, 
    logger: logging.Logger
) -> TelegramInvocationJob | InputValidationErrorResponse:
    try:
        body_raw = input["body"]
        try:
            body_parsed = json.loads(body_raw)
        except Exception:
            logger.exception("INPUT VALIDATION ERROR: raw request body is not valid JSON")
            return InputValidationErrorResponse()
        if not isinstance(body_parsed, dict):
            logger.warning("INPUT VALIDATION ERROR: parsed request body is malformed")
            return InputValidationErrorResponse()
        if len(body_parsed) == 0:
            logger.warning("INPUT VALIDATION ERROR: parsed request body is empty")
            return InputValidationErrorResponse()
    except Exception:
        logger.exception("INPUT VALIDATION ERROR: missing or malformed Lambda event body")
        return InputValidationErrorResponse()
    
    # Skip edit message events to only trigger answer generation on new messages("message")
    if "edited_message" in body_parsed.keys():
        logger.warning("Edited message event received, skipping.")
        return InputValidationErrorResponse()

    update_id = body_parsed.get("update_id")
    if not isinstance(update_id, int):
        logger.warning(f"INPUT VALIDATION ERROR: parsed request body's update_id is malformed")
        return InputValidationErrorResponse()
    if update_id < 0:
        logger.warning(f"INPUT VALIDATION ERROR: parsed request body's update_id must be a positive integer")
        return InputValidationErrorResponse()
    
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

    message_id = message.get("message_id")
    if not isinstance(message_id, int):
        logger.warning(f"INPUT VALIDATION ERROR: Telegram message message_id is malformed")
        return InputValidationErrorResponse()
    if message_id < 0:
        logger.warning(f"INPUT VALIDATION ERROR: Telegram message message_id must be a positive integer")
        return InputValidationErrorResponse()

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
    logger.info(f"Valid telegram request payload received: {json.dumps({
        "update_id": update_id,
        "message_id": message_id,
        "username": username,
        "chat_id": str(chat_id),
        "message": text,
        "date": date
    })}")

    try:
        agent_input = TelegramMessageAgentInput(
            username=username,
            sender_id=sender_id,
            text=text,
            date=date
        )
        queue_message_payload = TelegramInvocationJob(
            update_id=update_id,
            message_id=message_id,
            agent_input=agent_input
        )
        return queue_message_payload

    except ValidationError:
        return InputValidationErrorResponse(
            sender_id = sender_id,
            error_msg = "INPUT VALIDATION ERROR: validated Telegram input failed schema validation"
        )
