import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

from ..domain.storage import StorageFailure
from .settings import Settings


class R2Store:
    def __init__(self, settings: Settings):
        self.bucket = settings.r2_bucket
        self.expiry = settings.signed_url_seconds
        self.client = boto3.client("s3", region_name="auto",
            endpoint_url=f"https://{settings.r2_account_id}.r2.cloudflarestorage.com",
            aws_access_key_id=settings.r2_access_key_id.get_secret_value(),
            aws_secret_access_key=settings.r2_secret_access_key.get_secret_value(),
            config=Config(signature_version="s3v4", connect_timeout=10,
                read_timeout=45, retries={"max_attempts": 2},
                request_checksum_calculation="when_required", response_checksum_validation="when_required"))

    def put(self, key: str, content: bytes, content_type: str) -> None:
        try:
            self.client.put_object(Bucket=self.bucket, Key=key, Body=content,
                ContentType=content_type, CacheControl="private, no-store")
        except (BotoCoreError, ClientError) as exc:
            raise StorageFailure(503, "No se pudieron guardar las imágenes en R2; reintenta") from exc

    def signed_get(self, key: str) -> str:
        try:
            return self.client.generate_presigned_url("get_object",
                Params={"Bucket": self.bucket, "Key": key}, ExpiresIn=self.expiry)
        except (BotoCoreError, ClientError) as exc:
            raise StorageFailure(503, "No se pudo autorizar la lectura de la imagen") from exc

    def close(self):
        self.client.close()
