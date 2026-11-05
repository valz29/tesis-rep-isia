from contextlib import asynccontextmanager
import httpx
from fastapi import FastAPI
from pydantic import ValidationError
from starlette.responses import JSONResponse
from starlette.exceptions import HTTPException

from .application.images import EvaluationImages
from .infrastructure.settings import Settings
from .infrastructure.supabase import SupabaseGateway
from .infrastructure.r2 import R2Store
from .infrastructure.imaging import PillowInspector
from .presentation.http import routes


class BodyLimit:
    """Bound total multipart body, including chunked requests, before parsing files."""
    def __init__(self, app, limit: int):
        self.app, self.limit = app, limit

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        length = dict(scope["headers"]).get(b"content-length")
        if length and (not length.isdigit() or int(length) > self.limit):
            return await JSONResponse({"detail": "La carga supera el tamaño permitido"}, status_code=413)(scope, receive, send)
        used = 0
        async def bounded_receive():
            nonlocal used
            message = await receive()
            used += len(message.get("body", b""))
            if used > self.limit:
                raise HTTPException(413, "La carga supera el tamaño permitido")
            return message
        await self.app(scope, bounded_receive, send)


def create_app(service: EvaluationImages | None = None) -> FastAPI:
    # Injected services are test-only. Production fails closed on missing configuration.
    @asynccontextmanager
    async def lifespan(app):
        if service is not None:
            app.state.images = service
            yield
        else:
            try:
                settings = Settings()
            except (ValidationError, ValueError):
                # Do not let Pydantic print raw environment values in startup logs.
                raise RuntimeError("Configuración del servidor incompleta o inválida. Revisa backend/.env.example") from None
            with httpx.Client(timeout=30, follow_redirects=False) as client:
                store = R2Store(settings)
                app.state.images = EvaluationImages(SupabaseGateway(settings, client), store, settings.max_image_bytes, PillowInspector())
                try:
                    yield
                finally:
                    store.close()

    app = FastAPI(title="Retinazo · Images", version="0.1.0", lifespan=lifespan)
    # 3 files of up to 20 MiB (absolute supported maximum), plus multipart overhead.
    app.add_middleware(BodyLimit, limit=(service.max_image_bytes if service else 20*1024*1024)*3+1024*1024)
    routes(app)
    return app


app = create_app()
