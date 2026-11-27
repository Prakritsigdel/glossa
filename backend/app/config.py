from pydantic import AliasChoices, Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
import logging
import os

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

_DEFAULT_JWT_SECRET = "dev-only-change-this-secret"
_MIN_JWT_SECRET_LENGTH = 32

# Env var names that populate the jwt_secret field. Strict production
# validation only applies when one of these is explicitly set, so tests
# and local development that rely on the default secret keep working.
_JWT_SECRET_ENV_VARS = ("JWT_SECRET", "GLOSSA_JWT_SECRET")


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://glossa:glossa@localhost:5432/glossa"
    jwt_secret: str = _DEFAULT_JWT_SECRET
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

    @model_validator(mode="after")
    def _validate_jwt_secret(self) -> "Settings":
        """Reject missing, default, or weak JWT secrets in production.

        Strict validation only applies when JWT_SECRET is explicitly
        provided via environment variable. When unset, the default
        development secret is allowed with a warning so local development
        and existing test sessions are not invalidated.
        """
        env = (self.content_environment or "").strip().lower()
        secret = self.jwt_secret or ""

        explicitly_provided = any(
            var in os.environ for var in _JWT_SECRET_ENV_VARS
        )

        if not explicitly_provided:
            if secret == _DEFAULT_JWT_SECRET:
                logging.getLogger("glossa.config").warning(
                    "Using default development JWT_SECRET. "
                    "Set GLOSSA_JWT_SECRET for production."
                )
            return self

        # Explicitly provided: enforce production-grade requirements.
        if env == "production":
            if not secret:
                raise ValueError(
                    "JWT_SECRET is required in production (set GLOSSA_JWT_SECRET)"
                )
            if secret == _DEFAULT_JWT_SECRET:
                raise ValueError(
                    "JWT_SECRET must not be the default development value in production"
                )
            if len(secret) < _MIN_JWT_SECRET_LENGTH:
                raise ValueError(
                    f"JWT_SECRET must be at least {_MIN_JWT_SECRET_LENGTH} characters in production"
                )
        else:
            if secret == _DEFAULT_JWT_SECRET:
                logging.getLogger("glossa.config").warning(
                    "Using default development JWT_SECRET in non-production. "
                    "Set GLOSSA_JWT_SECRET for production."
                )
        return self


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
