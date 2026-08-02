import hashlib
import importlib
import json
import sys
from pathlib import Path
from unittest.mock import Mock

import pytest


MOCK_TELE_BOT_API_KEY = "1234567890:ABCDEFGHIJKLMNOPQRSTUVWXYZ"
MOCK_TELE_PID = 123456789
MOCK_UPDATE_ID = 172376328
MOCK_MESSAGE_ID = 67
MOCK_SQS_QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/123456789012/test.fifo"


@pytest.fixture
def handler_module(monkeypatch):
    repo_root = Path(__file__).resolve().parents[1]
    shared_src = repo_root / "src" / "shared"
    monkeypatch.syspath_prepend(str(shared_src))

    monkeypatch.setenv("TELE_BOT_API_KEY", MOCK_TELE_BOT_API_KEY)
    monkeypatch.setenv("TELE_PID", str(MOCK_TELE_PID))
    monkeypatch.setenv("SQS_QUEUE_URL", MOCK_SQS_QUEUE_URL)

    fake_boto3 = Mock()
    fake_boto3.client.return_value = Mock()
    monkeypatch.setitem(sys.modules, "boto3", fake_boto3)

    import src.lambdas.webhook.handler as module

    return importlib.reload(module)


def make_event(
    message=None,
    raw_body=None,
    update_id=MOCK_UPDATE_ID,
    **body_overrides,
):
    body = {}
    headers = {
        "x-telegram-bot-api-secret-token": hashlib.sha256(
            MOCK_TELE_BOT_API_KEY.encode()
        ).hexdigest()
    }
    if update_id is not None:
        body["update_id"] = update_id
    if message is not None:
        body["message"] = message
    body.update(body_overrides)
    return {
        "headers": headers,
        "body": raw_body if raw_body is not None else json.dumps(body),
    }


def make_message(**overrides):
    message = {
        "message_id": MOCK_MESSAGE_ID,
        "from": {"id": MOCK_TELE_PID},
        "chat": {"id": MOCK_TELE_PID},
        "text": "Hello, World!",
    }
    message.update(overrides)
    return message


def test_webhook_enqueues_valid_invocation_job(handler_module):
    out = handler_module.handler(make_event(make_message(date=1721385600)), None)

    assert out == {"statusCode": 200, "body": ""}
    handler_module.sqs_client.send_message.assert_called_once()

    call = handler_module.sqs_client.send_message.call_args.kwargs
    assert call["QueueUrl"] == MOCK_SQS_QUEUE_URL
    assert call["MessageGroupId"] == str(MOCK_TELE_PID)
    assert call["MessageDeduplicationId"] == f"telegram-update-{MOCK_UPDATE_ID}"
    assert json.loads(call["MessageBody"]) == {
        "update_id": MOCK_UPDATE_ID,
        "message_id": MOCK_MESSAGE_ID,
        "agent_input": {
            "username": None,
            "sender_id": str(MOCK_TELE_PID),
            "text": "Hello, World!",
            "date": "19072024",
        },
    }


def test_handler_returns_200_for_non_dict_lambda_event(handler_module):
    assert handler_module.handler("not-a-dict", None) == {
        "statusCode": 200,
        "body": "",
    }


@pytest.mark.parametrize(
    "event",
    [
        make_event(),
        make_event(raw_body="not-json"),
        make_event(raw_body="{}"),
        make_event(make_message(), update_id=None),
        make_event(make_message(), update_id="invalid"),
        make_event(message=[]),
        make_event(message={}),
        make_event(make_message(**{"from": {}})),
        make_event(make_message(chat={})),
        make_event(make_message(message_id=None)),
        make_event(make_message(text="")),
        make_event(make_message(text=123)),
    ],
)
def test_handler_acknowledges_invalid_payloads(handler_module, event):
    assert handler_module.handler(event, None) == {"statusCode": 200, "body": ""}
    handler_module.sqs_client.send_message.assert_not_called()


def test_handler_ignores_edited_message_events(handler_module):
    out = handler_module.handler(make_event(edited_message=make_message()), None)

    assert out == {"statusCode": 200, "body": ""}
    handler_module.sqs_client.send_message.assert_not_called()


def test_handler_rejects_missing_telegram_secret(handler_module):
    event = make_event(make_message())
    event["headers"] = {}

    assert handler_module.handler(event, None) == {"statusCode": 401, "body": ""}
    handler_module.sqs_client.send_message.assert_not_called()


def test_handler_rejects_invalid_telegram_secret(handler_module):
    event = make_event(make_message())
    event["headers"]["x-telegram-bot-api-secret-token"] = "invalid-secret"

    assert handler_module.handler(event, None) == {"statusCode": 401, "body": ""}
    handler_module.sqs_client.send_message.assert_not_called()


def test_handler_acknowledges_wrong_sender_id(handler_module):
    out = handler_module.handler(
        make_event(make_message(**{"from": {"id": MOCK_TELE_PID + 1}})),
        None,
    )

    assert out == {"statusCode": 200, "body": ""}
    handler_module.sqs_client.send_message.assert_not_called()


def test_handler_returns_500_when_sqs_enqueue_fails(handler_module):
    handler_module.sqs_client.send_message.side_effect = RuntimeError("boom")

    out = handler_module.handler(make_event(make_message()), None)

    assert out == {"statusCode": 500, "body": ""}


def test_validate_input_accepts_valid_payload_with_date(handler_module):
    """Test successful date conversion from Unix UTC to DDMMYYYY."""
    out = handler_module._validate_input(
        input=make_event(make_message(date=1721385600)),
        logger=handler_module.logger,
    )

    assert out.update_id == MOCK_UPDATE_ID
    assert out.message_id == MOCK_MESSAGE_ID
    assert out.agent_input.sender_id == str(MOCK_TELE_PID)
    assert out.agent_input.text == "Hello, World!"
    assert out.agent_input.date == "19072024"
