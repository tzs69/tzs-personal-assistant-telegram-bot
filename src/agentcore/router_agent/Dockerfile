FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim

WORKDIR /router_agent

COPY ./agentcore/router_agent/requirements.txt ./requirements.txt

RUN uv pip install --system --no-cache -r requirements.txt

COPY ./agentcore/router_agent/ ./
COPY ./shared/schemas.py ./schemas.py
COPY ./shared/agentcore_memory.py ./agentcore_memory.py

# Agent runtime entry point 
EXPOSE 8080

CMD ["uv", "run", "uvicorn", "agent:app", "--host", "0.0.0.0", "--port", "8080", "--no-access-log"]
