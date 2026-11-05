from io import BytesIO
import warnings
from PIL import Image, UnidentifiedImageError
from ..domain.storage import StorageFailure


class PillowInspector:
    def inspect(self, content: bytes, content_type: str) -> tuple[int, int]:
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("error", Image.DecompressionBombWarning)
                with Image.open(BytesIO(content)) as decoded:
                    if Image.MIME.get(decoded.format) != content_type:
                        raise StorageFailure(422, "El formato real de la imagen no coincide")
                    width, height = decoded.size
                    if width * height > 40_000_000:
                        raise StorageFailure(422, "La resolución supera el límite de carga")
                    decoded.verify()
                with Image.open(BytesIO(content)) as decoded:
                    decoded.load()  # Decode pixels too: JPEG.verify() alone is insufficient.
                return width, height
        except (UnidentifiedImageError, OSError, SyntaxError,
                Image.DecompressionBombError, Image.DecompressionBombWarning) as exc:
            raise StorageFailure(422, "Uno de los archivos no es una imagen válida") from exc
