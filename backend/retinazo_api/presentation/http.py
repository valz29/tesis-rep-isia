from typing import Annotated
from uuid import UUID

from fastapi import Depends, FastAPI, File, HTTPException, UploadFile, Request
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from ..application.images import EvaluationImages
from ..domain.storage import Actor, StorageFailure


def routes(app: FastAPI):
    bearer = HTTPBearer(auto_error=False)

    def images(request: Request) -> EvaluationImages:
        return request.app.state.images

    def authenticate(service: Annotated[EvaluationImages, Depends(images)],
                     credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]) -> Actor:
        if credentials is None or credentials.scheme.lower() != "bearer":
            raise HTTPException(401, "Inicia sesión para continuar")
        return service.gateway.authenticate(credentials.credentials)

    @app.exception_handler(StorageFailure)
    async def failure_handler(_request: Request, exc: StorageFailure):
        return JSONResponse(status_code=exc.status, content={"detail": exc.message},
                            headers={"Cache-Control": "no-store"})

    @app.get("/health")
    def health():
        return {"service": "retinazo-images", "model": "not_integrated"}

    @app.put("/v1/evaluations/{evaluation_id}/images", status_code=204)
    def upload(evaluation_id: UUID,
               files: Annotated[list[UploadFile], File()],
               actor: Annotated[Actor, Depends(authenticate)],
               service: Annotated[EvaluationImages, Depends(images)]):
        try:
            if len(files) != 3:
                raise StorageFailure(422, "Selecciona exactamente tres imágenes")
            contents = [file.file.read(service.max_image_bytes + 1) for file in files]
            service.upload(actor, str(evaluation_id), contents)
        finally:
            for file in files:
                file.file.close()

    @app.get("/v1/evaluations/{evaluation_id}/images")
    def downloads(evaluation_id: UUID, actor: Annotated[Actor, Depends(authenticate)],
                  service: Annotated[EvaluationImages, Depends(images)]):
        return JSONResponse({"images": service.downloads(actor, str(evaluation_id))},
                            headers={"Cache-Control": "no-store"})
