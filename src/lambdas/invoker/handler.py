import json
import logging
import os
import boto3
from pydantic import ValidationError

from typing import Dict
import requests
from schemas import TelegramMessageAgentResponse, TelegramInvocationJob

AGENT_RUNTIME_ARN = os.environ.get("AGENT_RUNTIME_ARN")
AGENT_RUNTIME_REGION = os.environ.get("AGENT_RUNTIME_REGION", "us-east-1")
TELE_PID = os.environ.get("TELE_PID")
TELE_BOT_API_KEY=os.environ.get("TELE_BOT_API_KEY", "")
TELE_BOT_URL = f"https://api.telegram.org/bot{TELE_BOT_API_KEY}/sendMessage"
TELE_BOT_REQUEST_TIMEOUT_SECONDS = 10

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

agentcore_client = boto3.client("bedrock-agentcore", region_name=AGENT_RUNTIME_REGION)


def handler(event, context):
    if not isinstance(event, dict):
        raise ValueError(
            f"Invalid Lambda event format, expected dict, got {type(event)}"
        )

    records = event.get("Records")
    if not isinstance(records, list):
        raise ValueError(
            f"Invalid SQS records format, expected list, got {type(records)}"
        )
    if len(records) == 0:
        raise ValueError("Empty SQS records list")

    for record in records:
        invocation_job = _validate_record(record=record)
        agent_input = invocation_job.agent_input
        sender_id = agent_input.sender_id

        try:
            # Pass validated input to agent runtime for answer generation
            response = agentcore_client.invoke_agent_runtime(
                agentRuntimeArn=AGENT_RUNTIME_ARN,
                payload=agent_input.model_dump_json(),
                contentType="application/json",
                accept="application/json",
                qualifier="DEFAULT",
            )
        except Exception:
            logger.exception("AgentCore invocation failed")
            raise

        response_body = response["response"].read().decode("utf-8")
        agent_response = TelegramMessageAgentResponse.model_validate_json(response_body)
        text = agent_response.text

        
        # TEMPORARY ONLY: WILL BE REMOVED ONCE RESPONSE CHUNKING IS IN PLACE
        if len(text) > 4096:
            text = text[:4096]


        payload_json = {
            "chat_id": sender_id,
            "text": text
        }
        response = requests.post(
            url=TELE_BOT_URL,
            json=payload_json,
            timeout=TELE_BOT_REQUEST_TIMEOUT_SECONDS
        )
        try:
            response.raise_for_status()
        except requests.HTTPError as error:
            # Treat Telegram 400 responses as permanent failures so retries do not block the FIFO queue
            if error.response is not None and error.response.status_code == 400:
                logger.error(f"Permanent Telegram delivery failure: {error.response.text}")
                return
            raise


def _validate_record(
    record: Dict,
) -> TelegramInvocationJob:
    if not isinstance(record, dict):
        raise ValueError("RECORD VALIDATION ERROR: malformed SQS record")
    if len(record) == 0:
        raise ValueError("RECORD VALIDATION ERROR: empty SQS record")

    # Validate record body
    try:
        body_raw = record["body"]
        body_parsed = json.loads(body_raw)
    except (KeyError, TypeError, json.JSONDecodeError) as error:
        raise ValueError(
            "RECORD VALIDATION ERROR: missing or malformed SQS record body"
        ) from error

    if not isinstance(body_parsed, dict) or len(body_parsed) == 0:
        raise ValueError(
            "RECORD VALIDATION ERROR: empty or malformed SQS record body"
        )

    try:
        invocation_job = TelegramInvocationJob.model_validate(body_parsed)
    except ValidationError as error:
        raise ValueError(
            "RECORD VALIDATION ERROR: SQS record body failed schema validation"
        ) from error

    update_id = invocation_job.update_id
    if update_id < 0:
        raise ValueError("RECORD VALIDATION ERROR: update_id must be a positive integer")

    # Match sender_id field to my own Tele PID
    sender_id = invocation_job.agent_input.sender_id
    if sender_id != TELE_PID:
        raise ValueError(
            f"RECORD VALIDATION ERROR: sender_id of record {sender_id} "
            f"does not match allowed personal id {TELE_PID}"
        )

    logger.info(f"Valid agent input payload received: {invocation_job.agent_input.model_dump_json()}")

    return invocation_job
