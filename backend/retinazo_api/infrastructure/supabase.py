import httpx

from ..domain.storage import (
    Actor, ExpectedImage, StoredEvaluation, VerifiedImage, StorageFailure,
)
from .settings import Settings


class SupabaseGateway:
    def __init__(self, settings: Settings, client: httpx.Client):
        self.settings, self.client = settings, client

    def _request(self, path: str, token: str | None = None, body=None,
                 privileged: bool = False):
        key = (self.settings.supabase_service_key.get_secret_value()
               if privileged else self.settings.supabase_publishable_key)
        headers = {"apikey": key}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        elif privileged and not key.startswith("sb_secret_"):
            headers["Authorization"] = f"Bearer {key}"
        try:
            response = self.client.request("POST" if body is not None else "GET",
                self.settings.supabase_url + path, headers=headers, json=body)
        except httpx.HTTPError as exc:
            raise StorageFailure(503, "No se pudo comprobar la sesión o los registros") from exc
        if response.status_code in (401, 403):
            raise StorageFailure(403, "Tu cuenta no tiene acceso a esta operación")
        if response.status_code >= 400:
            if response.status_code in (400, 409) and privileged:
                raise StorageFailure(409, "El borrador o los permisos cambiaron; actualiza y reintenta")
            raise StorageFailure(503, "No se pudo consultar o actualizar la evaluación")
        return response.json() if response.content else None

    def authenticate(self, token: str) -> Actor:
        user = self._request("/auth/v1/user", token)
        if not user.get("email_confirmed_at"):
            raise StorageFailure(403, "Confirma tu correo antes de continuar")
        # An ID and role are accepted only from the configured Supabase project.
        from uuid import UUID
        try:
            uid = str(UUID(user["id"]))
        except (ValueError, KeyError) as exc:
            raise StorageFailure(403, "La identidad no es válida") from exc
        rows = self._request(f"/rest/v1/profiles?id=eq.{uid}&select=role,is_active", token)
        if len(rows) != 1 or rows[0].get("is_active") is not True or rows[0].get("role") not in ("professional", "admin"):
            raise StorageFailure(403, "Tu cuenta no está activa")
        return Actor(uid, token)

    def evaluation(self, actor: Actor, evaluation_id: str) -> StoredEvaluation:
        # Forward the user JWT so RLS handles current patient ownership and admin access.
        rows = self._request(f"/rest/v1/evaluations?id=eq.{evaluation_id}&select=id,status,evaluation_images(*)", actor.token)
        if not rows:
            raise StorageFailure(404, "La evaluación no está disponible")
        row = rows[0]
        return StoredEvaluation(row["id"], row["status"], tuple(
            ExpectedImage(m["position"], m["sha256"], m["content_type"], m["byte_size"],
                          m["upload_status"] == "uploaded", m.get("storage_provider"),
                          m.get("storage_bucket"), m.get("object_key"))
            for m in row["evaluation_images"]))

    def finish(self, actor: Actor, evaluation: StoredEvaluation,
               images: list[VerifiedImage], bucket: str) -> None:
        self._request("/rest/v1/rpc/finish_r2_upload", privileged=True, body={
            "actor_id_input": actor.id, "evaluation_id_input": evaluation.id,
            "images_input": [{"position": m.expected.position, "sha256": m.expected.sha256,
                "content_type": m.expected.content_type, "byte_size": len(m.content),
                "storage_bucket": bucket, "object_key": m.expected.object_key(evaluation.id),
                "width": m.width, "height": m.height} for m in images],
        })
