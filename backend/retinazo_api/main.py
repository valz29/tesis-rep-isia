from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI
from pydantic import ValidationError

from .application.images import EvaluationImages
from .infrastructure.imaging import PillowInspector
from .infrastructure.r2 import R2Store
from .infrastructure.settings import Settings
from .infrastructure.supabase import SupabaseGateway
from .presentation.http import routes
from .presentation.middleware import BodyLimit


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
                raise RuntimeError(
                    "Configuración del servidor incompleta o inválida. "
                    "Revisa backend/.env.example"
                ) from None
            with httpx.Client(timeout=30, follow_redirects=False) as client:
                store = R2Store(settings)
                app.state.images = EvaluationImages(
                    SupabaseGateway(settings, client),
                    store,
                    settings.max_image_bytes,
                    PillowInspector(),
                )
                try:
                    yield
                finally:
                    store.close()

    app = FastAPI(title="Retinazo · Images", version="0.1.0", lifespan=lifespan)
    # 3 files of up to 20 MiB (absolute supported maximum), plus multipart overhead.
    max_image_bytes = service.max_image_bytes if service else 20 * 1024 * 1024
    app.add_middleware(BodyLimit, limit=max_image_bytes * 3 + 1024 * 1024)
    routes(app)
    return app


app = create_app()
