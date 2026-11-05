from dataclasses import dataclass
from typing import Protocol


class StorageFailure(Exception):
    def __init__(self, status: int, message: str):
        self.status, self.message = status, message
        super().__init__(message)


@dataclass(frozen=True)
class Actor:
    id: str
    token: str


@dataclass(frozen=True)
class ExpectedImage:
    position: int
    sha256: str
    content_type: str
    byte_size: int
    uploaded: bool = False
    provider: str | None = None
    bucket: str | None = None
    key: str | None = None

    def object_key(self, evaluation_id: str) -> str:
        extension = {"image/jpeg": "jpg", "image/png": "png"}.get(self.content_type)
        if not extension:
            raise StorageFailure(422, "Solo se admiten imágenes JPEG y PNG")
        return f"evaluations/{evaluation_id}/{self.position}-{self.sha256}.{extension}"


@dataclass(frozen=True)
class StoredEvaluation:
    id: str
    status: str
    images: tuple[ExpectedImage, ...]


@dataclass(frozen=True)
class VerifiedImage:
    expected: ExpectedImage
    content: bytes
    width: int
    height: int


class EvaluationGateway(Protocol):
    def authenticate(self, token: str) -> Actor: ...
    def evaluation(self, actor: Actor, evaluation_id: str) -> StoredEvaluation: ...
    def finish(self, actor: Actor, evaluation: StoredEvaluation,
               images: list[VerifiedImage], bucket: str) -> None: ...


class ObjectStore(Protocol):
    bucket: str
    def put(self, key: str, content: bytes, content_type: str) -> None: ...
    def signed_get(self, key: str) -> str: ...


class ImageInspector(Protocol):
    def inspect(self, content: bytes, content_type: str) -> tuple[int, int]: ...
