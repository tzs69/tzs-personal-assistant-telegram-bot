import importlib
import json
from unittest.mock import Mock

import pytest


@pytest.fixture
def handler_module(monkeypatch):
    monkeypatch.setenv("TELE_BOT_API_KEY", "test-bot-api-key")

    import src.lambdas.mcp_tools.router_agent_tools.handler as module

    return importlib.reload(module)


def make_context(tool_name):
    context = Mock()
    context.client_context.custom = {
        "bedrockAgentCoreToolName": tool_name,
    }
    return context


def test_send_telegram_message_posts_expected_request(handler_module, monkeypatch):
    response = Mock()
    response.json.return_value = {
        "ok": True,
        "result": {"date": 0},
    }
    post = Mock(return_value=response)
    monkeypatch.setattr(handler_module.requests, "post", post)

    result = handler_module.send_telegram_message("Hello", 123)

    assert result == {"ok": True, "date": "01/01/1970 00:00"}
    post.assert_called_once_with(
        url="https://api.telegram.org/bottest-bot-api-key/sendMessage",
        json={"chat_id": 123, "text": "Hello"},
        timeout=10,
    )
    response.json.assert_called_once_with()


def test_send_telegram_message_returns_telegram_api_error(handler_module, monkeypatch):
    response = Mock()
    response.json.return_value = {
        "ok": False,
        "error_code": 400,
        "description": "Bad Request: chat not found",
    }
    monkeypatch.setattr(handler_module.requests, "post", Mock(return_value=response))

    result = handler_module.send_telegram_message("Hello", 123)

    assert result == {
        "ok": False,
        "error": "400: Bad Request: chat not found",
    }


def test_handler_dispatches_gateway_prefixed_tool_name(handler_module, monkeypatch):
    send_message = Mock(return_value={"ok": True, "date": "12/08/2026 04:53"})
    monkeypatch.setitem(
        handler_module.TOOLS,
        "send_telegram_message",
        send_message,
    )
    event = {"text": "Hello", "sender_id": "123"}
    context = make_context("router-agent-tools___send_telegram_message")

    result = handler_module.handler(event, context)

    send_message.assert_called_once_with(text="Hello", sender_id="123")
    assert result == {
        "content": json.dumps({"ok": True, "date": "12/08/2026 04:53"})
    }


@pytest.mark.parametrize(
    ("raw_name", "expected"),
    [
        ("router-agent-tools___send_telegram_message", "send_telegram_message"),
        ("send_telegram_message", "send_telegram_message"),
    ],
)
def test_resolve_tool_name(handler_module, raw_name, expected):
    assert handler_module._resolve_tool_name(make_context(raw_name)) == expected


def test_handler_rejects_unknown_tool(handler_module):
    context = make_context("router-agent-tools___unknown_tool")

    result = handler_module.handler({}, context)

    assert result == {"error": "Unknown tool: unknown_tool"}


def test_resolve_tool_name_returns_none_for_missing_context(handler_module):
    assert handler_module._resolve_tool_name(None) is None
