from pydantic import BaseModel

class InputValidationErrorResponse(BaseModel):
    sender_id: str | None = None
    error_msg: str | None = None

class TelegramMessageAgentInput(BaseModel):
    username: str | None = None
    sender_id: str
    text: str
    date: str

class TelegramMessageAgentResponse(BaseModel):
    text: str

class TelegramInvocationJob(BaseModel):
    update_id: int
    message_id: int
    agent_input: TelegramMessageAgentInput
