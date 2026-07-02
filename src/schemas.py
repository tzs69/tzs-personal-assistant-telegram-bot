from pydantic import BaseModel, ConfigDict

class TelegramMessageUserInput(BaseModel):
    username: str | None
    sender_id: int
    text: str
    date: int

class TelegramMessageAgentResponse(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)
    text: str
    error: BaseException | None
