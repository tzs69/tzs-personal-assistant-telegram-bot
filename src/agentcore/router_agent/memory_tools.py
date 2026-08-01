from typing import Callable
from strands import tool
from agentcore_memory import MemoryManagementService


def create_long_term_memory_tool(
    memory: MemoryManagementService,
    sender_id: str
) -> Callable[[str], str]:
    @tool(name="retrieve_long_term_memory")
    def retrieve_long_term_memory(query: str) -> str:
        """
        Search TZS's long-term memories for relevant personal facts,
        preferences, past decisions, projects, or older discussions.

        Use this when the current request depends on personal context that is
        not available in the supplied recent conversation history.

        Args:
            query: A specific, standalone semantic search query describing the
                information needed. Include the relevant subject and context
                instead of vague references such as "that" or "it".
        """
        result = memory.retrieve_relevant_memories(
            sender_id=sender_id,
            query=query,
            top_k=5
        )
        return result or "No relevant long-term memories were found."

    return retrieve_long_term_memory
