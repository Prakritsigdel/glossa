from pydantic import BaseModel, ConfigDict, EmailStr, Field


class Credentials(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class Registration(Credentials):
    name: str = Field(min_length=1, max_length=80)


class ProfileUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    hero_index: int | None = Field(default=None, ge=0, le=1)
    language_id: str | None = Field(default=None, max_length=40)


class UserOut(BaseModel):
    id: int
    name: str
    email: EmailStr
    hero_index: int
    hero_class_name: str
    language_id: str
    xp: int
    xp_to_next_level: int
    level: int
    streak: int
    words_found: int
    lessons_completed: int
    model_config = ConfigDict(from_attributes=True)


class AuthOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class AnswerIn(BaseModel):
    exercise_id: str
    selected_option_id: str | None = None
    selected_pairs: dict[str, str] | None = None


class AttemptIn(BaseModel):
    answers: list[AnswerIn] = Field(min_length=1)


class LeaderboardEntryOut(BaseModel):
    rank: int
    name: str
    level: int
    class_name: str
    xp: int
    hero_index: int
    is_current_user: bool = False
