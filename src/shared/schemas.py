from pydantic import BaseModel, ConfigDict

class InputValidationErrorResponse(BaseModel):
    sender_id: str | None = None
    error_msg: str | None = None

class TelegramMessageUserInput(BaseModel):
    username: str | None = None
    sender_id: str
    text: str
    date: str

class TelegramMessageAgentResponse(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)
    text: str
    error: BaseException | None = None
