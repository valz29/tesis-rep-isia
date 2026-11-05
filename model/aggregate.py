"""Agregacion clinica por ojo y por paciente ("worst grade wins").

Modulo puro (sin torch) para poder probarlo y reutilizarlo en el backend.
Es apoyo al tamizaje, no diagnostico.

Reglas:
- Una imagen cuenta solo si es graduable y su grado es un entero 0..4.
  Cualquier otra salida del modelo es invalida y no entra al calculo.
- Grado del ojo = peor grado entre sus imagenes validas.
- Un hallazgo referible (grado >= 2) es concluyente aunque haya pocas fotos
  validas: una sola foto con lesion basta para derivar.
- Para descartar (grado < 2) se exigen al menos `min_valid` imagenes validas;
  si no, el ojo queda "no_concluyente". Nunca se asume grado 0 por falta de datos.
- Grado del paciente = peor grado entre sus ojos. Si algun ojo es no concluyente
  y el otro no es referible, el paciente es no concluyente.
- El promedio de probabilidades es solo un dato auxiliar; no decide el grado.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence

REFERABLE_GRADE = 2
URGENT_GRADE = 3  # severa / proliferativa: derivacion urgente
DEFAULT_MIN_VALID = 2  # PENDIENTE de confirmar con la especialista.

CONCLUSIVE = "concluyente"
INCONCLUSIVE = "no_concluyente"


@dataclass(frozen=True)
class ImageResult:
    grade: object  # int 0..4 esperado; cualquier otra cosa es invalida
    gradable: bool = True
    probs: Sequence[float] | None = None  # 5 puntuaciones softmax, opcional


@dataclass(frozen=True)
class EyeResult:
    status: str
    grade: int | None
    n_valid: int
    n_total: int
    referable: bool | None
    urgent: bool | None
    mean_probs: tuple[float, ...] | None  # auxiliar, no decide el grado


@dataclass(frozen=True)
class PatientResult:
    status: str
    grade: int | None
    referable: bool | None
    urgent: bool | None


def is_valid_grade(grade: object) -> bool:
    return isinstance(grade, int) and not isinstance(grade, bool) and 0 <= grade <= 4


def _is_usable(image: ImageResult) -> bool:
    return bool(image.gradable) and is_valid_grade(image.grade)


def _mean_probs(images: Sequence[ImageResult]) -> tuple[float, ...] | None:
    rows = [tuple(float(p) for p in i.probs) for i in images if i.probs is not None and len(i.probs) == 5]
    if not rows:
        return None
    return tuple(sum(col) / len(rows) for col in zip(*rows))


def aggregate_eye(images: Sequence[ImageResult], min_valid: int = DEFAULT_MIN_VALID) -> EyeResult:
    if min_valid < 1:
        raise ValueError("min_valid debe ser >= 1")
    usable = [i for i in images if _is_usable(i)]
    worst = max((i.grade for i in usable), default=None)
    mean = _mean_probs(usable)
    if worst is not None and worst >= REFERABLE_GRADE:
        return EyeResult(CONCLUSIVE, worst, len(usable), len(images), True, worst >= URGENT_GRADE, mean)
    if len(usable) < min_valid:
        return EyeResult(INCONCLUSIVE, None, len(usable), len(images), None, None, mean)
    return EyeResult(CONCLUSIVE, worst, len(usable), len(images), False, False, mean)


def aggregate_patient(eyes: Sequence[EyeResult]) -> PatientResult:
    if not eyes:
        return PatientResult(INCONCLUSIVE, None, None, None)
    conclusive = [e for e in eyes if e.status == CONCLUSIVE]
    worst = max((e.grade for e in conclusive), default=None)
    if worst is not None and worst >= REFERABLE_GRADE:
        return PatientResult(CONCLUSIVE, worst, True, worst >= URGENT_GRADE)
    if len(conclusive) < len(eyes):
        return PatientResult(INCONCLUSIVE, None, None, None)
    return PatientResult(CONCLUSIVE, worst, False, False)
