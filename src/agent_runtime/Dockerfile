FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim

WORKDIR /agent_runtime

COPY ./agent_runtime/requirements.txt ./requirements.txt

RUN uv pip install --system --no-cache -r requirements.txt

COPY ./agent_runtime/ ./
COPY ./shared/schemas.py ./schemas.py

# Agent runtime entry point 
EXPOSE 8080

CMD ["uv", "run", "uvicorn", "agent:app", "--host", "0.0.0.0", "--port", "8080", "--no-access-log"]