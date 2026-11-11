from dataclasses import replace
import hashlib
from io import BytesIO

from fastapi.testclient import TestClient
from PIL import Image
import pytest

from retinazo_api.application.images import EvaluationImages
from retinazo_api.domain.storage import Actor, ExpectedImage, StoredEvaluation, StorageFailure
from retinazo_api.infrastructure.imaging import PillowInspector
from retinazo_api.main import create_app

EVAL = "30000000-0000-0000-0000-000000000001"
USER = "10000000-0000-0000-0000-000000000001"


def picture(n):
    buf = BytesIO()
    Image.new("RGB", (4, 4), (n*30, 20, 30)).save(buf, format="PNG")
    return buf.getvalue()


class Gateway:
    def __init__(self, contents):
        self.record = StoredEvaluation(EVAL, "draft", tuple(ExpectedImage(
            i+1, hashlib.sha256(b).hexdigest(), "image/png", len(b))
            for i, b in enumerate(contents)))
        self.finalized = 0
        self.forbidden = False

    def authenticate(self, token):
        if token != "synthetic-session":
            raise StorageFailure(403, "Sesión no válida")
        return Actor(USER, token)

    def evaluation(self, actor, evaluation_id):
        if self.forbidden or evaluation_id != EVAL:
            raise StorageFailure(404, "La evaluación no está disponible")
        return self.record

    def finish(self, actor, evaluation, images, bucket):
        self.finalized += 1
        self.record = replace(self.record, status="pending_analysis", images=tuple(
            replace(i.expected, uploaded=True, provider="cloudflare_r2", bucket=bucket,
                    key=i.expected.object_key(EVAL)) for i in images))


class Store:
    bucket = "retinazo-test"
    def __init__(self):
        self.objects = {}
        self.fail_at = None

    def put(self, key, content, content_type):
        if len(self.objects) == self.fail_at:
            raise StorageFailure(503, "R2 no disponible")
        self.objects[key] = content

    def signed_get(self, key):
        return f"https://test.r2.cloudflarestorage.com/{key}?signed=test"


@pytest.fixture
def setup():
    contents = [picture(i) for i in range(1, 4)]
    gateway, store = Gateway(contents), Store()
    service = EvaluationImages(gateway, store, 1024, PillowInspector())
    with TestClient(create_app(service)) as client:
        yield contents, gateway, store, client


def upload(client, contents, auth=True):
    return client.put(f"/v1/evaluations/{EVAL}/images",
        headers={"Authorization": "Bearer synthetic-session"} if auth else {},
        files=[("files", (f"{i}.png", b, "image/png")) for i, b in enumerate(contents)])


def test_valid_upload_is_verified_atomic_in_database_and_idempotent(setup):
    contents, gateway, store, client = setup
    assert upload(client, contents).status_code == 204
    assert gateway.finalized == 1 and len(store.objects) == 3
    assert gateway.record.status == "pending_analysis"
    assert upload(client, contents).status_code == 204
    assert gateway.finalized == 1  # Network retries do not produce a second evaluation.
    links = client.get(f"/v1/evaluations/{EVAL}/images",
        headers={"Authorization": "Bearer synthetic-session"})
    assert links.status_code == 200 and len(links.json()["images"]) == 3
    assert links.headers["cache-control"] == "no-store"


def test_unauthenticated_or_inaccessible_evaluation_never_writes(setup):
    contents, gateway, store, client = setup
    assert upload(client, contents, auth=False).status_code == 401
    gateway.forbidden = True
    assert upload(client, contents).status_code == 404
    assert not store.objects and gateway.finalized == 0


def test_partial_upload_cannot_finalize_and_retry_reuses_objects(setup):
    contents, gateway, store, client = setup
    store.fail_at = 1
    assert upload(client, contents).status_code == 503
    assert len(store.objects) == 1 and gateway.finalized == 0
    store.fail_at = None
    assert upload(client, contents).status_code == 204
    assert len(store.objects) == 3


@pytest.mark.parametrize("variant", ["two", "changed", "invalid_encoding", "too_large"])
def test_complete_set_is_checked_before_first_r2_write(setup, variant):
    contents, gateway, store, client = setup
    if variant == "two":
        contents = contents[:2]
    else:
        contents[2] = b"invalid" if variant != "too_large" else b"x"*1025
        if variant != "changed":
            m = gateway.record.images[2]
            gateway.record = replace(gateway.record, images=(*gateway.record.images[:2],
                replace(m, sha256=hashlib.sha256(contents[2]).hexdigest(), byte_size=len(contents[2]))))
    assert upload(client, contents).status_code in (409, 413, 422)
    assert not store.objects and gateway.finalized == 0


def test_saved_reference_cannot_sign_an_arbitrary_object(setup):
    contents, gateway, store, client = setup
    assert upload(client, contents).status_code == 204
    m = gateway.record.images[0]
    gateway.record = replace(gateway.record, images=(replace(m, key="another-patient/photo.png"), *gateway.record.images[1:]))
    result = client.get(f"/v1/evaluations/{EVAL}/images", headers={"Authorization": "Bearer synthetic-session"})
    assert result.status_code == 409


def test_total_request_limit_applies_before_parsing(setup):
    _, _, store, client = setup
    response = client.put(f"/v1/evaluations/{EVAL}/images", content=b"x"*(1024*1024+3073),
                          headers={"Authorization": "Bearer synthetic-session"})
    assert response.status_code == 413 and not store.objects


def test_inactive_patient_never_writes_but_retains_download_access(setup):
    contents, gateway, store, client = setup
    assert upload(client, contents).status_code == 204
    gateway.record = replace(gateway.record, patient_active=False)
    previous = dict(store.objects)
    assert upload(client, contents).status_code == 409
    assert store.objects == previous and gateway.finalized == 1
    response = client.get(f"/v1/evaluations/{EVAL}/images",
                          headers={"Authorization": "Bearer synthetic-session"})
    assert response.status_code == 200 and len(response.json()["images"]) == 3


def test_administrator_cannot_upload_images(setup):
    contents, gateway, store, client = setup
    gateway.authenticate = lambda token: Actor(USER, token, "admin")
    assert upload(client, contents).status_code == 403
    assert not store.objects and gateway.finalized == 0
