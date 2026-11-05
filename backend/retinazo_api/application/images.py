import hashlib
import re
from ..domain.storage import (
    Actor, EvaluationGateway, ObjectStore, ImageInspector, StorageFailure, VerifiedImage,
)


class EvaluationImages:
    def __init__(self, gateway: EvaluationGateway, store: ObjectStore,
                 max_image_bytes: int, inspector: ImageInspector):
        self.gateway, self.store = gateway, store
        self.max_image_bytes = max_image_bytes
        self.inspector = inspector

    def upload(self, actor: Actor, evaluation_id: str,
               contents: list[bytes]) -> None:
        record = self.gateway.evaluation(actor, evaluation_id)
        expected = sorted(record.images, key=lambda i: i.position)
        if record.status != "draft":
            # Already finalized requests are idempotent only when every byte matches.
            if len(expected) == 3 and len(contents) == 3 and all(
                image.uploaded and image.provider == "cloudflare_r2"
                and image.bucket == self.store.bucket
                and image.key == image.object_key(record.id)
                and len(content) == image.byte_size
                and hashlib.sha256(content).hexdigest() == image.sha256
                for image, content in zip(expected, contents)
            ):
                return
            raise StorageFailure(409, "Esta evaluación ya no admite nuevas imágenes")
        if len(contents) != 3 or [i.position for i in expected] != [1, 2, 3]:
            raise StorageFailure(422, "Se requieren exactamente tres imágenes del mismo ojo")
        verified = []
        # Validate the complete set before writing even the first object.
        for image, content in zip(expected, contents):
            if not 0 < len(content) <= self.max_image_bytes:
                raise StorageFailure(413, "Una imagen supera el tamaño permitido")
            if (len(content) != image.byte_size or
                not re.fullmatch(r"[0-9a-f]{64}", image.sha256) or
                hashlib.sha256(content).hexdigest() != image.sha256):
                raise StorageFailure(409, "Las imágenes no coinciden con el borrador guardado")
            image.object_key(record.id)  # Enforces the supported encoding.
            width, height = self.inspector.inspect(content, image.content_type)
            verified.append(VerifiedImage(image, content, width, height))
        for image in verified:
            self.store.put(image.expected.object_key(record.id), image.content,
                           image.expected.content_type)
        # A privileged RPC atomically re-checks identity, ownership and all metadata.
        self.gateway.finish(actor, record, verified, self.store.bucket)

    def downloads(self, actor: Actor, evaluation_id: str) -> list[dict]:
        record = self.gateway.evaluation(actor, evaluation_id)
        links = []
        for image in sorted(record.images, key=lambda i: i.position):
            if not image.uploaded:
                continue
            if (image.provider != "cloudflare_r2" or image.bucket != self.store.bucket
                    or image.key != image.object_key(record.id)):
                raise StorageFailure(409, "La referencia de almacenamiento no es válida")
            links.append({"position": image.position,
                          "url": self.store.signed_get(image.key)})
        return links
