import httpx
import pytest
from retinazo_api.infrastructure.settings import Settings
from retinazo_api.infrastructure.supabase import SupabaseGateway
from retinazo_api.domain.storage import StorageFailure


def settings(**extra):
    return Settings(_env_file=None, supabase_url="https://example.supabase.co",
        supabase_publishable_key="sb_publishable_test", supabase_service_key="sb_secret_server_test",
        r2_account_id="a"*32, r2_access_key_id="synthetic-key",r2_secret_access_key="synthetic-secret", **extra)


@pytest.mark.parametrize("confirmed,active,expected", [(True,True,True),(False,True,False),(True,False,False)])
def test_identity_is_verified_by_auth_and_protected_profile(confirmed, active, expected):
    requests = []
    def handle(request):
        requests.append(request)
        assert request.headers["apikey"] == "sb_publishable_test"
        assert request.headers["authorization"] == "Bearer synthetic-user-token"
        if request.url.path == "/auth/v1/user":
            return httpx.Response(200,json={"id":"10000000-0000-0000-0000-000000000001",
                "email_confirmed_at":"2026-01-01" if confirmed else None,
                "user_metadata":{"role":"admin"}})
        return httpx.Response(200,json=[{"role":"professional","is_active":active}])
    with httpx.Client(transport=httpx.MockTransport(handle)) as client:
        gateway = SupabaseGateway(settings(),client)
        if expected:
            assert gateway.authenticate("synthetic-user-token").id.endswith("0001")
        else:
            with pytest.raises(StorageFailure): gateway.authenticate("synthetic-user-token")


def test_bad_configuration_does_not_expose_server_credentials_in_startup_error(monkeypatch):
    from fastapi.testclient import TestClient
    from retinazo_api.main import create_app
    monkeypatch.setenv("SUPABASE_SERVICE_KEY","private-sentinel-never-print")
    with pytest.raises(RuntimeError) as error:
        with TestClient(create_app()): pass
    assert "private-sentinel-never-print" not in str(error.value)


def test_domain_and_application_do_not_import_infrastructure():
    import ast
    from pathlib import Path
    root=Path(__file__).parents[1]/"retinazo_api"
    for folder in ["domain","application"]:
        for path in (root/folder).glob("*.py"):
            for node in ast.walk(ast.parse(path.read_text())):
                if isinstance(node,ast.ImportFrom):
                    assert not any(x in (node.module or '').split('.') for x in ['fastapi','httpx','boto3','PIL','infrastructure','presentation'])
