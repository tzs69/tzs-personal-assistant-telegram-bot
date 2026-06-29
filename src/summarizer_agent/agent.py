import os
from bedrock_agentcore import BedrockAgentCoreApp
from strands import Agent

AGENT_RUNTIME_MODEL_ID = os.environ.get("AGENT_RUNTIME_MODEL_ID")

app = BedrockAgentCoreApp()

agent = Agent(
    model=AGENT_RUNTIME_MODEL_ID,
    system_prompt="You are a unread email summarizer agent."
)

@app.entrypoint
def invoke(payload):
    return "Agent runtime handler invocation success."


if __name__ == "__main__":
    app.run()