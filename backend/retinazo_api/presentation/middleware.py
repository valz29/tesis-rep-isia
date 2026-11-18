from starlette.exceptions import HTTPException
from starlette.responses import JSONResponse


class BodyLimit:
    """Bound total multipart body, including chunked requests, before parsing files."""

    def __init__(self, app, limit: int):
        self.app = app
        self.limit = limit

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        length = dict(scope["headers"]).get(b"content-length")
        if length and (not length.isdigit() or int(length) > self.limit):
            response = JSONResponse(
                {"detail": "La carga supera el tamaño permitido"}, status_code=413
            )
            return await response(scope, receive, send)
        used = 0

        async def bounded_receive():
            nonlocal used
            message = await receive()
            used += len(message.get("body", b""))
            if used > self.limit:
                raise HTTPException(413, "La carga supera el tamaño permitido")
            return message

        await self.app(scope, bounded_receive, send)
