import hashlib
import importlib
import json
import os
import sys
from pathlib import Path
from unittest.mock import Mock

import pytest


MOCK_UPDATE_ID = 172376328
MOCK_MESSAGE_ID = 67
MOCK_SQS_QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/123456789012/test.fifo"


def make_telegram_event(tele_pid, tele_bot_api_key):
    body = {
        "update_id": MOCK_UPDATE_ID,
        "message": {
            "message_id": MOCK_MESSAGE_ID,
            "from": {
                "id": int(tele_pid),
                "username": "integration_test",
            },
            "chat": {
                "id": int(tele_pid),
                "username": "integration_test",
            },
            "text": "Integration test: reply with a short acknowledgement.",
            "date": 1721385600,
        },
    }
    return {
        "headers": {
            "x-telegram-bot-api-secret-token": hashlib.sha256(
                tele_bot_api_key.encode()
            ).hexdigest()
        },
        "body": json.dumps(body),
    }


@pytest.mark.integration
def test_webhook_to_invoker_to_router_agent_runtime(monkeypatch):
    """Run both Lambda handlers locally while invoking the deployed router runtime."""
    if os.environ.get("RUN_LIVE_INTEGRATION_TESTS") != "1":
        pytest.skip("set RUN_LIVE_INTEGRATION_TESTS=1 to run live integration tests")

    required_env_vars = [
        "AGENT_RUNTIME_ARN",
        "AGENT_RUNTIME_REGION",
        "TELE_PID",
        "TELE_BOT_API_KEY",
    ]
    missing_env_vars = [name for name in required_env_vars if not os.environ.get(name)]
    if missing_env_vars:
        pytest.skip(f"missing required variables: {', '.join(missing_env_vars)}")

    agent_runtime_arn = os.environ["AGENT_RUNTIME_ARN"]
    agent_runtime_region = os.environ["AGENT_RUNTIME_REGION"]
    tele_pid = os.environ["TELE_PID"]
    tele_bot_api_key = os.environ["TELE_BOT_API_KEY"]

    repo_root = Path(__file__).resolve().parents[1]
    monkeypatch.syspath_prepend(str(repo_root / "src" / "shared"))
    monkeypatch.setenv("TELE_BOT_API_KEY", tele_bot_api_key)
    monkeypatch.setenv("TELE_PID", tele_pid)
    monkeypatch.setenv("SQS_QUEUE_URL", MOCK_SQS_QUEUE_URL)
    monkeypatch.setenv("AGENT_RUNTIME_ARN", agent_runtime_arn)
    monkeypatch.setenv("AGENT_RUNTIME_REGION", agent_runtime_region)

    sys.modules.pop("src.lambdas.webhook.handler", None)
    sys.modules.pop("src.lambdas.invoker.handler", None)

    import src.lambdas.webhook.handler as webhook_handler

    webhook_handler = importlib.reload(webhook_handler)
    sqs_client = Mock()
    monkeypatch.setattr(webhook_handler, "sqs_client", sqs_client)

    webhook_output = webhook_handler.handler(
        make_telegram_event(tele_pid, tele_bot_api_key),
        None,
    )

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

    invoker_output = invoker_handler.handler(sqs_event, None)

    assert invoker_output is None
