import importlib
import json
import os
import sys
from io import BytesIO
from pathlib import Path
from unittest.mock import Mock

import pytest
import requests


MOCK_TELE_PID = 123456789
AGENTCORE_FAILURE_TEXT = "AgentCore invocation failed. Message was not processed."


@pytest.fixture
def handler_module(monkeypatch):
    repo_root = Path(__file__).resolve().parents[1]
    shared_src = repo_root / "src" / "shared"
    monkeypatch.syspath_prepend(str(shared_src))

    monkeypatch.setenv("TELE_PID", str(MOCK_TELE_PID))
    monkeypatch.setenv("AGENT_RUNTIME_REGION", "us-east-1")
    monkeypatch.setenv("AGENT_RUNTIME_ARN", "fake-agent-runtime-arn")

    fake_boto3 = Mock()
    fake_boto3.client.return_value = Mock()
    monkeypatch.setitem(sys.modules, "boto3", fake_boto3)

    import src.lambdas.webhook.handler as module

    return importlib.reload(module)


@pytest.fixture
def successful_agentcore_client():
    fake_client = Mock()
    fake_client.invoke_agent_runtime.return_value = {
        "response": BytesIO(b'{"text":"ok","error":null}')
    }
    return fake_client


def make_event(message=None, **body_overrides):
    body = {}
    if message is not None:
        body["message"] = message
    body.update(body_overrides)
    return {"body": json.dumps(body)}


def make_message(**overrides):
    message = {
        "from": {"id": MOCK_TELE_PID},
        "chat": {"id": MOCK_TELE_PID},
        "text": "Hello, World!",
    }
    message.update(overrides)
    return message


def test_webhook_contract(handler_module, successful_agentcore_client, monkeypatch):
    monkeypatch.setattr(handler_module, "client", successful_agentcore_client)

    out = handler_module.handler(make_event(make_message()), None)

    assert out == {
        "method": "sendMessage",
        "chat_id": str(MOCK_TELE_PID),
        "text": "ok",
    }

    successful_agentcore_client.invoke_agent_runtime.assert_called_once()
    call = successful_agentcore_client.invoke_agent_runtime.call_args.kwargs
    assert call["agentRuntimeArn"] == "fake-agent-runtime-arn"
    assert call["contentType"] == "application/json"
    assert call["accept"] == "application/json"
    assert call["qualifier"] == "DEFAULT"

    agent_payload = json.loads(call["payload"])
    assert agent_payload["sender_id"] == str(MOCK_TELE_PID)
    assert agent_payload["text"] == "Hello, World!"


def test_handler_returns_200_for_non_dict_lambda_event(handler_module):
    assert handler_module.handler("not-a-dict", None) == ("", 200)


@pytest.mark.parametrize(
    ("event", "expected"),
    [
        ({}, ("", 400)),
        ({"body": "not-json"}, ("", 400)),
        ({"body": "{}"}, ("", 400)),
        (make_event(message=[]), ("", 400)),
        (make_event(message={}), ("", 400)),
        (make_event(make_message(**{"from": {}})), ("", 400)),
        (make_event(make_message(chat={})), ("", 400)),
        (make_event(make_message(text="")), ("", 400)),
        (make_event(make_message(text=123)), ("", 400)),
    ],
)
def test_handler_rejects_invalid_payloads(handler_module, event, expected):
    assert handler_module.handler(event, None) == expected


def test_handler_ignores_edited_message_events(handler_module):
    out = handler_module.handler(make_event(edited_message=make_message()), None)

    assert out == ("", 200)


def test_handler_rejects_wrong_sender_id(handler_module):
    out = handler_module.handler(make_event(make_message(**{"from": {"id": MOCK_TELE_PID + 1}})), None)

    assert out == ("", 400)


def test_handler_returns_send_message_when_agentcore_invocation_fails(handler_module, monkeypatch):
    failing_client = Mock()
    failing_client.invoke_agent_runtime.side_effect = RuntimeError("boom")
    monkeypatch.setattr(handler_module, "client", failing_client)

    out = handler_module.handler(make_event(make_message()), None)

    assert out == {
        "method": "sendMessage",
        "chat_id": str(MOCK_TELE_PID),
        "text": AGENTCORE_FAILURE_TEXT,
    }


def test_validate_input_accepts_valid_payload_with_date(handler_module):
    '''Test date successful date conversion from unix UTC to DDMMYYYY'''
    out = handler_module._validate_input(
        input=make_event(make_message(date=1721385600)),
        logger=handler_module.logger,
    )

    assert out.sender_id == str(MOCK_TELE_PID)
    assert out.text == "Hello, World!"
    assert out.date == "19072024"


def itest_message(tele_pid):
    message = {
        "from": {"id": tele_pid, "username": "integration_test"},
        "chat": {"id": tele_pid, "username": "integration_test"},
        "text": "Integration test: reply with a short acknowledgement.",
    }
    return message


@pytest.mark.integration
def test_handler_invokes_router_agent_runtime(monkeypatch):
    '''
    Hybrid integration test:
     - Mocks deployed webhook lambda by using local handler with mock PID
     - Agent Invocation hits real router agent runtime deployed in AgentCore
    '''
    if os.environ.get("RUN_LIVE_INTEGRATION_TESTS") != "1":
        pytest.skip("set RUN_LIVE_INTEGRATION_TESTS=1 to run live AgentCore integration test")

    required_env_vars = ["AGENT_RUNTIME_ARN", "AGENT_RUNTIME_REGION", "TELE_PID"]
    missing_env_vars = [name for name in required_env_vars if not os.environ.get(name)]
    if missing_env_vars:
        pytest.skip(f"{', '.join(missing_env_vars)}")

    repo_root = Path(__file__).resolve().parents[1]
    monkeypatch.syspath_prepend(str(repo_root / "src" / "shared"))
    monkeypatch.setenv("TELE_PID", str(MOCK_TELE_PID))

    sys.modules.pop("src.lambdas.webhook.handler", None)
    import src.lambdas.webhook.handler as live_handler_module
    live_handler_module = importlib.reload(live_handler_module)

    event = make_event(itest_message(MOCK_TELE_PID))
    out = live_handler_module.handler(event, None)

    assert isinstance(out, dict)
    assert out["method"] == "sendMessage"
    assert out["chat_id"] == str(MOCK_TELE_PID)
    assert out["text"]
    assert out["text"] != AGENTCORE_FAILURE_TEXT
