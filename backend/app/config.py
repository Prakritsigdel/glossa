from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict

# The two supported content environments.
#
# "production" (default) keeps the publication safeguards fully active:
# only explicitly published AND verified lessons are playable.
#
# "development" unlocks the structurally complete but linguistically
# provisional curriculum inside an isolated development database so the
# 15-lesson pilot can be played end to end before native-speaker
# verification finishes. It never changes stored verification flags.
CONTENT_ENVIRONMENTS = ("production", "development")

DEFAULT_CONTENT_ENVIRONMENT = "production"


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://glossa:glossa@localhost:5432/glossa"
    jwt_secret: str = "dev-only-change-this-secret"
    access_token_minutes: int = 60 * 24 * 7
    cors_origins: str = "*"
    # Content environment. Unknown values fail closed to "production".
    # Explicit alias so GLOSSA_CONTENT_ENVIRONMENT works without adding a
    # global env prefix that would break DATABASE_URL / JWT_SECRET.
    content_environment: str = Field(
        default=DEFAULT_CONTENT_ENVIRONMENT,
        validation_alias=AliasChoices(
            "glossa_content_environment", "content_environment"
        ),
    )
    model_config = SettingsConfigDict(
        env_file=".env", extra="ignore", populate_by_name=True
    )


settings = Settings()


def content_environment() -> str:
    """Return the active content environment ("production" or "development").

    Any unknown or empty value fails closed to "production" so a typo can
    never unlock provisional content by accident.
    """
    value = (settings.content_environment or "").strip().lower()
    return value if value in CONTENT_ENVIRONMENTS else DEFAULT_CONTENT_ENVIRONMENT


def development_content_enabled() -> bool:
    """True only when provisional curriculum gameplay is explicitly enabled."""
    return content_environment() == "development"
