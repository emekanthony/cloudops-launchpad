from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="APP_", env_file=".env")

    database_url: str = "postgresql+psycopg://cloudops:cloudops@localhost:5432/cloudops"
    app_version: str = "dev"


settings = Settings()
