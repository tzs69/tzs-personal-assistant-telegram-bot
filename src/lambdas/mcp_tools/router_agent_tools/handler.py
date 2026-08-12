import logging
import json
import os
import requests

from datetime import datetime, timezone
from typing import Dict

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

TELE_BOT_API_KEY = os.environ.get("TELE_BOT_API_KEY")


def format_utc_date(date_utc: int) -> str:
    """
    Converts a Unix/UTC timestamp into 'DD/MM/YYYY HH:MM' format.
    Falls back to stringified raw input if input is malformed.
    """
    date_format = '%d/%m/%Y %H:%M'
    
    try:
        return datetime.fromtimestamp(date_utc, tz=timezone.utc).strftime(date_format)
    except (ValueError, OverflowError):
        # Fallback and return utc value if input is out of range for a timestamp
        return str(date_utc)


# =======================================================================
#   TOOLS
# =======================================================================


def send_telegram_message(text: str, sender_id: int, timeout: int = 10) -> Dict:
    tele_bot_url = f"https://api.telegram.org/bot{TELE_BOT_API_KEY}/sendMessage"
    payload_json = {
        "chat_id": sender_id,
        "text": text
    }

    response_raw = requests.post(
        url=tele_bot_url,
        json=payload_json,
        timeout=timeout
    )

    response = response_raw.json()
    if not response["ok"]:
        error_code = response["error_code"]
        error_body = response["description"]
        logger.error(f"Telegram send message error ({error_code}): {error_body}")
        return {"ok": False, "error": f"{error_code}: {error_body}"}
    else:
        date_utc = response["result"]["date"]
        return {"ok": True, "date": format_utc_date(date_utc)}


# =======================================================================
#   TOOL DISPATCH
# =======================================================================


TOOLS = {
    "send_telegram_message": send_telegram_message,
}


def _resolve_tool_name(context):
    """Extract tool name from AgentCore Gateway client context (format: {target}___{tool_name})"""
    try:
        custom = context.client_context.custom
        raw = custom.get("bedrockAgentCoreToolName", "")
        if "___" in raw:
            return raw.split("___", 1)[1]
        return raw
    except (AttributeError, TypeError):
        return None


def handler(event, context):
    logger.debug(f"Received event: {json.dumps(event)}")

    tool_name = _resolve_tool_name(context)
    logger.info(f"Resolved tool: {tool_name}")

    if tool_name not in TOOLS:
        error_msg = f"Unknown tool: {tool_name}"
        logger.error(error_msg)
        return {"error": error_msg}

    result = TOOLS[tool_name](**event)
    return {"content": json.dumps(result)}
