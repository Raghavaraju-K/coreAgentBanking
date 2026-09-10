from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_env: str = "development"
    demo_bearer_token: str = "demo-token"
    jwt_issuer: str = ""
    jwt_audience: str = ""
    agent_core_api_key: str | None = None
    agent_core_base_url: str | None = None
    agent_core_model: str | None = None

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()