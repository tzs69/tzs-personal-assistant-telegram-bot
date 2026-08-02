import hashlib
import importlib
import json
import os
import sys
from pathlib import Path
from unittest.mock import Mock

import pytest


MOCK_TELE_BOT_API_KEY = "1234567890:ABCDEFGHIJKLMNOPQRSTUVWXYZ"
MOCK_TELE_PID = 123456789
MOCK_UPDATE_ID = 172376328
MOCK_MESSAGE_ID = 67
MOCK_SQS_QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/123456789012/test.fifo"


def make_telegram_event():
    body = {
        "update_id": MOCK_UPDATE_ID,
        "message": {
            "message_id": MOCK_MESSAGE_ID,
            "from": {
                "id": MOCK_TELE_PID,
                "username": "integration_test",
            },
            "chat": {
                "id": MOCK_TELE_PID,
                "username": "integration_test",
            },
            "text": "Integration test: reply with a short acknowledgement.",
            "date": 1721385600,
        },
    }
    return {
        "headers": {
            "x-telegram-bot-api-secret-token": hashlib.sha256(
                MOCK_TELE_BOT_API_KEY.encode()
            ).hexdigest()
        },
        "body": json.dumps(body),
    }


@pytest.mark.integration
def test_webhook_to_invoker_to_router_agent_runtime(monkeypatch):
    """Run both Lambda handlers locally while invoking the deployed router runtime."""
    if os.environ.get("RUN_LIVE_INTEGRATION_TESTS") != "1":
        pytest.skip("set RUN_LIVE_INTEGRATION_TESTS=1 to run live integration tests")

    required_env_vars = ["AGENT_RUNTIME_ARN", "AGENT_RUNTIME_REGION"]
    missing_env_vars = [name for name in required_env_vars if not os.environ.get(name)]
    if missing_env_vars:
        pytest.skip(f"missing required variables: {', '.join(missing_env_vars)}")

    agent_runtime_arn = os.environ["AGENT_RUNTIME_ARN"]
    agent_runtime_region = os.environ["AGENT_RUNTIME_REGION"]

    repo_root = Path(__file__).resolve().parents[1]
    monkeypatch.syspath_prepend(str(repo_root / "src" / "shared"))
    monkeypatch.setenv("TELE_BOT_API_KEY", MOCK_TELE_BOT_API_KEY)
    monkeypatch.setenv("TELE_PID", str(MOCK_TELE_PID))
    monkeypatch.setenv("SQS_QUEUE_URL", MOCK_SQS_QUEUE_URL)
    monkeypatch.setenv("AGENT_RUNTIME_ARN", agent_runtime_arn)
    monkeypatch.setenv("AGENT_RUNTIME_REGION", agent_runtime_region)

    sys.modules.pop("src.lambdas.webhook.handler", None)
    sys.modules.pop("src.lambdas.invoker.handler", None)

    import src.lambdas.webhook.handler as webhook_handler

    webhook_handler = importlib.reload(webhook_handler)
    sqs_client = Mock()
    monkeypatch.setattr(webhook_handler, "sqs_client", sqs_client)

    webhook_output = webhook_handler.handler(make_telegram_event(), None)

    assert webhook_output == {"statusCode": 200, "body": ""}
    sqs_client.send_message.assert_called_once()
    queued_message = sqs_client.send_message.call_args.kwargs

    sqs_event = {
        "Records": [
            {
                "messageId": "hybrid-integration-message-id",
                "body": queued_message["MessageBody"],
                "attributes": {
                    "MessageGroupId": queued_message["MessageGroupId"],
                    "MessageDeduplicationId": queued_message[
                        "MessageDeduplicationId"
                    ],
                },
                "eventSource": "aws:sqs",
            }
        ]
    }

    import src.lambdas.invoker.handler as invoker_handler

    invoker_handler = importlib.reload(invoker_handler)
    telegram_response = Mock()
    telegram_post = Mock(return_value=telegram_response)
    monkeypatch.setattr(invoker_handler.requests, "post", telegram_post)

    invoker_output = invoker_handler.handler(sqs_event, None)

    assert invoker_output is None
    telegram_post.assert_called_once()
    telegram_payload = telegram_post.call_args.kwargs["json"]
    assert telegram_payload["chat_id"] == str(MOCK_TELE_PID)
    assert telegram_payload["text"]
    telegram_response.raise_for_status.assert_called_once_with()
