from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://glossa:glossa@localhost:5432/glossa"
    jwt_secret: str = "dev-only-change-this-secret"
    access_token_minutes: int = 60 * 24 * 7
    cors_origins: str = "*"
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
