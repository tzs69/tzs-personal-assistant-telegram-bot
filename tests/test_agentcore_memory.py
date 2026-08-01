import importlib
import logging
import sys
from pathlib import Path
from types import ModuleType
from unittest.mock import Mock

import pytest


@pytest.fixture
def memory_service(monkeypatch):
    repo_root = Path(__file__).resolve().parents[1]
    monkeypatch.syspath_prepend(str(repo_root / "src" / "shared"))

    memory_client = Mock()
    memory_module = ModuleType("bedrock_agentcore.memory")
    memory_module.MemoryClient = Mock(return_value=memory_client)
    agentcore_module = ModuleType("bedrock_agentcore")
    agentcore_module.memory = memory_module
    monkeypatch.setitem(sys.modules, "bedrock_agentcore", agentcore_module)
    monkeypatch.setitem(sys.modules, "bedrock_agentcore.memory", memory_module)

    import agentcore_memory

    module = importlib.reload(agentcore_memory)
    service = module.MemoryManagementService(
        memory_id="memory-id",
        region="us-east-1",
        logger=logging.getLogger(__name__)
    )
    return service, memory_client


def test_retrieve_relevant_memories_formats_extracted_text(memory_service):
    service, client = memory_service
    client.retrieve_memories.return_value = [
        {"content": {"text": "TZS prefers concise answers."}, "score": 0.95},
        {"content": {"text": "TZS uses OCBC."}, "score": 0.82},
        {"content": {}},
        "invalid",
    ]

    result = service.retrieve_relevant_memories(
        sender_id="123",
        query="banking preferences",
        top_k=3
    )

    assert result == "1) TZS prefers concise answers.\n2) TZS uses OCBC."
    client.retrieve_memories.assert_called_once_with(
        memory_id="memory-id",
        namespace_path="/actor/123",
        query="banking preferences",
        top_k=3
    )


@pytest.mark.parametrize(
    ("sender_id", "query", "top_k"),
    [("", "query", 1), ("123", "", 1), ("123", "query", 0), ("123", "query", True)]
)
def test_retrieve_relevant_memories_rejects_invalid_arguments(
    memory_service,
    sender_id,
    query,
    top_k
):
    service, client = memory_service

    assert service.retrieve_relevant_memories(sender_id, query, top_k) == ""
    client.retrieve_memories.assert_not_called()


def test_fetch_short_term_memories_returns_strands_messages_oldest_first(memory_service):
    service, client = memory_service
    client.get_last_k_turns.return_value = [
        [
            {"role": "USER", "content": {"text": "Newest question"}},
            {"role": "ASSISTANT", "content": {"text": "Newest answer"}},
        ],
        [
            {"role": "USER", "content": {"text": "Oldest question"}},
            {"role": "ASSISTANT", "content": {"text": "Oldest answer"}},
        ],
    ]

    result = service.fetch_short_term_memories(sender_id="123", max_turns=2)

    assert result == [
        {"role": "user", "content": [{"text": "Oldest question"}]},
        {"role": "assistant", "content": [{"text": "Oldest answer"}]},
        {"role": "user", "content": [{"text": "Newest question"}]},
        {"role": "assistant", "content": [{"text": "Newest answer"}]},
    ]
    client.get_last_k_turns.assert_called_once_with(
        memory_id="memory-id",
        actor_id="123",
        session_id="telegram_123",
        k=2
    )


def test_fetch_short_term_memories_ignores_unsupported_or_empty_messages(memory_service):
    service, client = memory_service
    client.get_last_k_turns.return_value = [[
        {"role": "TOOL", "content": {"text": "Tool output"}},
        {"role": "USER", "content": {"text": ""}},
        {"role": "ASSISTANT", "content": {"text": "Usable answer"}},
        "invalid",
    ]]

    assert service.fetch_short_term_memories("123", 1) == [
        {"role": "assistant", "content": [{"text": "Usable answer"}]}
    ]


@pytest.mark.parametrize(
    ("sender_id", "max_turns"),
    [("", 1), (None, 1), ("123", 0), ("123", "1")]
)
def test_fetch_short_term_memories_rejects_invalid_arguments(
    memory_service,
    sender_id,
    max_turns
):
    service, client = memory_service

    assert service.fetch_short_term_memories(sender_id, max_turns) == []
    client.get_last_k_turns.assert_not_called()
