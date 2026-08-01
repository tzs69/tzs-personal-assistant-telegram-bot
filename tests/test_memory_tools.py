import sys
from pathlib import Path
from unittest.mock import Mock


def test_long_term_memory_tool_binds_sender_and_caps_results(monkeypatch):
    repo_root = Path(__file__).resolve().parents[1]
    monkeypatch.syspath_prepend(str(repo_root / "src" / "shared"))
    monkeypatch.syspath_prepend(str(repo_root / "src" / "agentcore" / "router_agent"))

    sys.modules.pop("memory_tools", None)
    from memory_tools import create_long_term_memory_tool

    memory = Mock()
    memory.retrieve_relevant_memories.return_value = "1) TZS uses OCBC."
    memory_tool = create_long_term_memory_tool(memory=memory, sender_id="123")

    assert memory_tool(query="Which bank does TZS use?") == "1) TZS uses OCBC."
    memory.retrieve_relevant_memories.assert_called_once_with(
        sender_id="123",
        query="Which bank does TZS use?",
        top_k=5
    )


def test_long_term_memory_tool_returns_clear_empty_result(monkeypatch):
    repo_root = Path(__file__).resolve().parents[1]
    monkeypatch.syspath_prepend(str(repo_root / "src" / "shared"))
    monkeypatch.syspath_prepend(str(repo_root / "src" / "agentcore" / "router_agent"))

    sys.modules.pop("memory_tools", None)
    from memory_tools import create_long_term_memory_tool

    memory = Mock()
    memory.retrieve_relevant_memories.return_value = ""
    memory_tool = create_long_term_memory_tool(memory=memory, sender_id="123")

    assert memory_tool(query="Unknown preference") == "No relevant long-term memories were found."
