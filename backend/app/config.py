from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    supabase_url: str = ""
    supabase_anon_key: str = ""
    supabase_service_role_key: str = ""
    supabase_key: str = ""
    groq_api_key: str = ""
    default_provider: str = "groq"
    cors_allowed_origins: str = "http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,http://127.0.0.1:5173,http://localhost:8080,http://127.0.0.1:8080"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    def auth_api_key(self) -> str:
        return self.supabase_anon_key or self.supabase_key

    def db_api_key(self) -> str:
        return self.supabase_service_role_key or self.supabase_key or self.supabase_anon_key


@lru_cache
def get_settings() -> Settings:
    return Settings()
