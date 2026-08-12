import importlib
import json
import sys
from io import BytesIO
from pathlib import Path
from unittest.mock import Mock

import pytest


MOCK_TELE_PID = "123456789"
MOCK_UPDATE_ID = 172376328
MOCK_MESSAGE_ID = 67
MOCK_AGENT_RUNTIME_ARN = "fake-agent-runtime-arn"


@pytest.fixture
def handler_module(monkeypatch):
    repo_root = Path(__file__).resolve().parents[1]
    shared_src = repo_root / "src" / "shared"
    monkeypatch.syspath_prepend(str(shared_src))

    monkeypatch.setenv("TELE_PID", MOCK_TELE_PID)
    monkeypatch.setenv("AGENT_RUNTIME_REGION", "us-east-1")
    monkeypatch.setenv("AGENT_RUNTIME_ARN", MOCK_AGENT_RUNTIME_ARN)

    fake_boto3 = Mock()
    fake_boto3.client.return_value = Mock()
    monkeypatch.setitem(sys.modules, "boto3", fake_boto3)

    import src.lambdas.invoker.handler as module

    return importlib.reload(module)


def make_invocation_job(**overrides):
    job = {
        "update_id": MOCK_UPDATE_ID,
        "message_id": MOCK_MESSAGE_ID,
        "agent_input": {
            "username": "integration_test",
            "sender_id": MOCK_TELE_PID,
            "text": "Hello, World!",
            "date": "19072024",
        },
    }
    job.update(overrides)
    return job


def make_sqs_event(body=None):
    return {
        "Records": [
            {
                "messageId": "test-sqs-message-id",
                "body": json.dumps(body if body is not None else make_invocation_job()),
                "attributes": {
                    "MessageGroupId": MOCK_TELE_PID,
                    "MessageDeduplicationId": f"telegram-update-{MOCK_UPDATE_ID}",
                },
                "eventSource": "aws:sqs",
            }
        ]
    }


@pytest.fixture
def successful_agentcore_client():
    fake_client = Mock()
    fake_client.invoke_agent_runtime.return_value = {
        "response": BytesIO(b'{"text":"ok"}')
    }
    return fake_client


def test_invoker_contract(handler_module, successful_agentcore_client, monkeypatch):
    monkeypatch.setattr(handler_module, "agentcore_client", successful_agentcore_client)

    out = handler_module.handler(make_sqs_event(), None)

    assert out is None
    successful_agentcore_client.invoke_agent_runtime.assert_called_once()
    call = successful_agentcore_client.invoke_agent_runtime.call_args.kwargs
    assert call["agentRuntimeArn"] == MOCK_AGENT_RUNTIME_ARN
    assert call["contentType"] == "application/json"
    assert call["accept"] == "application/json"
    assert call["qualifier"] == "DEFAULT"
    assert json.loads(call["payload"]) == make_invocation_job()["agent_input"]


@pytest.mark.parametrize(
    "event",
    [
        "not-a-dict",
        {},
        {"Records": None},
        {"Records": []},
        {"Records": [None]},
        {"Records": [{}]},
        {"Records": [{"body": "not-json"}]},
        {"Records": [{"body": "{}"}]},
        {"Records": [{"body": json.dumps(make_invocation_job(update_id=-1))}]},
        {
            "Records": [
                {
                    "body": json.dumps(
                        make_invocation_job(
                            agent_input={
                                "username": None,
                                "sender_id": "wrong-sender",
                                "text": "Hello, World!",
                                "date": "19072024",
                            }
                        )
                    )
                }
            ]
        },
    ],
)
def test_handler_raises_for_malformed_sqs_events(handler_module, event):
    with pytest.raises(ValueError):
        handler_module.handler(event, None)


def test_handler_reraises_agentcore_failure(handler_module, monkeypatch):
    failing_client = Mock()
    failing_client.invoke_agent_runtime.side_effect = RuntimeError("boom")
    monkeypatch.setattr(handler_module, "agentcore_client", failing_client)

    with pytest.raises(RuntimeError, match="boom"):
        handler_module.handler(make_sqs_event(), None)
