"""Preprocesamiento unico de fondo de ojo: recorte circular -> CLAHE -> resize -> normalizacion.

Este modulo debe ser importado tanto por el entrenamiento como por el endpoint de
inferencia. No dupliques esta logica en otro lugar. No depende de torch: devuelve
arrays numpy; quien llame convierte a tensor (torch.from_numpy).

Una imagen en la que no se encuentra retina lanza InvalidFundusImage; el llamador
debe tratarla como "no concluyente" y nunca como grado 0.
"""
from __future__ import annotations

import cv2
import numpy as np
from PIL import Image, ImageOps

INPUT_SIZE = 224  # tamano de entrada de RETFound (ViT-L/16)
# Medias/desviaciones de normalizacion. PENDIENTE: confirmar contra el repo de RETFound
# que se use (por defecto ImageNet) antes de entrenar con ese modelo.
NORM_MEAN = (0.485, 0.456, 0.406)
NORM_STD = (0.229, 0.224, 0.225)

CLAHE_CLIP_LIMIT = 2.0
CLAHE_TILE_GRID = (8, 8)
FUNDUS_THRESHOLD = 10  # nivel de gris (0-255) por encima del cual un pixel se considera retina
MIN_FUNDUS_FRACTION = 0.05  # fraccion minima de la imagen que debe ser retina
MIN_SIDE = 32


class InvalidFundusImage(ValueError):
    """La imagen no contiene un fondo de ojo utilizable."""


def to_rgb_array(image: Image.Image | np.ndarray) -> np.ndarray:
    """Convierte a uint8 HxWx3 RGB, respetando la orientacion EXIF si es PIL."""
    if isinstance(image, Image.Image):
        image = np.asarray(ImageOps.exif_transpose(image).convert("RGB"))
    array = np.asarray(image)
    if array.dtype != np.uint8 or array.ndim != 3 or array.shape[2] != 3:
        raise InvalidFundusImage("Se espera una imagen RGB uint8 de forma HxWx3.")
    if min(array.shape[:2]) < MIN_SIDE:
        raise InvalidFundusImage("Imagen demasiado pequena.")
    return array


def circular_crop(rgb: np.ndarray) -> np.ndarray:
    """Recorta un cuadrado alrededor de la retina y pone en negro lo que queda fuera del circulo."""
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    mask = cv2.GaussianBlur(gray, (5, 5), 0) > FUNDUS_THRESHOLD
    if mask.mean() < MIN_FUNDUS_FRACTION:
        raise InvalidFundusImage("No se detecta retina en la imagen.")
    ys, xs = np.where(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    cy, cx = (y0 + y1) / 2.0, (x0 + x1) / 2.0
    radius = max(y1 - y0, x1 - x0) / 2.0
    # Cuadrado centrado en la retina; se rellena con negro donde se sale de la imagen.
    side = int(round(radius * 2))
    top, left = int(round(cy - radius)), int(round(cx - radius))
    canvas = np.zeros((side, side, 3), dtype=np.uint8)
    sy0, sx0 = max(top, 0), max(left, 0)
    sy1, sx1 = min(top + side, rgb.shape[0]), min(left + side, rgb.shape[1])
    canvas[sy0 - top : sy1 - top, sx0 - left : sx1 - left] = rgb[sy0:sy1, sx0:sx1]
    yy, xx = np.ogrid[:side, :side]
    inside = (yy - (side - 1) / 2.0) ** 2 + (xx - (side - 1) / 2.0) ** 2 <= (side / 2.0) ** 2
    canvas[~inside] = 0
    return canvas


def apply_clahe(rgb: np.ndarray) -> np.ndarray:
    """CLAHE sobre el canal de luminancia (LAB); conserva el color."""
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB)
    clahe = cv2.createCLAHE(clipLimit=CLAHE_CLIP_LIMIT, tileGridSize=CLAHE_TILE_GRID)
    lab[:, :, 0] = clahe.apply(lab[:, :, 0])
    return cv2.cvtColor(lab, cv2.COLOR_LAB2RGB)


def preprocess_image(image: Image.Image | np.ndarray, size: int = INPUT_SIZE) -> np.ndarray:
    """Recorte circular + CLAHE + resize. Devuelve uint8 sizexsizex3 RGB (util para inspeccion visual)."""
    cropped = circular_crop(to_rgb_array(image))
    enhanced = apply_clahe(cropped)
    return cv2.resize(enhanced, (size, size), interpolation=cv2.INTER_AREA)


def normalize(rgb: np.ndarray) -> np.ndarray:
    """uint8 HxWx3 -> float32 3xHxW normalizado."""
    scaled = rgb.astype(np.float32) / 255.0
    scaled = (scaled - np.asarray(NORM_MEAN, dtype=np.float32)) / np.asarray(NORM_STD, dtype=np.float32)
    return np.ascontiguousarray(scaled.transpose(2, 0, 1), dtype=np.float32)


def preprocess(image: Image.Image | np.ndarray, size: int = INPUT_SIZE) -> np.ndarray:
    """Pipeline completo: entrada PIL/ndarray RGB -> float32 3xsizexsize listo para el modelo."""
    return normalize(preprocess_image(image, size))
