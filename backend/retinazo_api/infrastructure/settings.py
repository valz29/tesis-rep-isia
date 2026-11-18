import base64
import json
import re
from urllib.parse import urlsplit

from pydantic import SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    supabase_url: str
    supabase_publishable_key: str
    supabase_service_key: SecretStr
    r2_account_id: str
    r2_access_key_id: SecretStr
    r2_secret_access_key: SecretStr
    r2_bucket: str = "retinazo-retinas"
    max_image_bytes: int = 10 * 1024 * 1024
    signed_url_seconds: int = 60

    @model_validator(mode="after")
    def validate_configuration(self):
        uri = urlsplit(self.supabase_url)
        if uri.scheme != "https" or not uri.hostname or uri.username or uri.query or uri.fragment or uri.path not in ("", "/"):
            raise ValueError("SUPABASE_URL must be an HTTPS project origin")
        self.supabase_url = self.supabase_url.rstrip("/")
        if not self.supabase_publishable_key.startswith("sb_publishable_"):
            raise ValueError("SUPABASE_PUBLISHABLE_KEY must be public")
        secret = self.supabase_service_key.get_secret_value()
        if not secret.startswith("sb_secret_"):
            try:
                claims = json.loads(base64.urlsafe_b64decode(secret.split(".")[1] + "=="))
                if claims.get("role") != "service_role":
                    raise ValueError()
            except (ValueError, IndexError):
                raise ValueError("SUPABASE_SERVICE_KEY must be a server credential") from None
        if not re.fullmatch(r"[a-f0-9]{32}", self.r2_account_id):
            raise ValueError("R2_ACCOUNT_ID is required")
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]{1,61}[a-z0-9]", self.r2_bucket):
            raise ValueError("R2_BUCKET must be a valid private bucket name")
        if not 1 <= self.max_image_bytes <= 20 * 1024 * 1024 or not 15 <= self.signed_url_seconds <= 300:
            raise ValueError("Invalid upload size or signed URL lifetime")
        if not all(s.get_secret_value() and "REPLACE" not in s.get_secret_value()
                   for s in [self.r2_access_key_id, self.r2_secret_access_key]):
            raise ValueError("Bucket-scoped R2 credentials are required")
        return self
