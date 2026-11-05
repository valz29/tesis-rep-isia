import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from preprocessing import (  # noqa: E402
    INPUT_SIZE,
    InvalidFundusImage,
    apply_clahe,
    circular_crop,
    preprocess,
    preprocess_image,
)


def synthetic_fundus(height=300, width=400, center=None, radius=120, seed=0):
    rng = np.random.default_rng(seed)
    cy, cx = center or (height // 2, width // 2)
    yy, xx = np.ogrid[:height, :width]
    disc = (yy - cy) ** 2 + (xx - cx) ** 2 <= radius**2
    image = np.zeros((height, width, 3), dtype=np.uint8)
    base = np.array([150, 80, 40], dtype=np.float32)
    noise = rng.normal(0, 4, (height, width, 1))
    image[disc] = np.clip(base + noise, 0, 255).astype(np.uint8)[disc]
    return image


def test_circular_crop_is_square_and_tight():
    out = circular_crop(synthetic_fundus(radius=120))
    assert out.shape[0] == out.shape[1]
    assert 235 <= out.shape[0] <= 245
    assert out[0, 0].sum() == 0 and out[-1, -1].sum() == 0  # esquinas fuera del circulo
    h = out.shape[0] // 2
    assert out[h, h].sum() > 0  # centro conserva la retina


def test_crop_handles_off_center_and_clipped_retina():
    out = circular_crop(synthetic_fundus(center=(150, 60), radius=110))  # sale del borde izquierdo
    assert out.shape[0] == out.shape[1] and out.shape[0] > 100


def test_clahe_raises_local_contrast_and_keeps_shape():
    rng = np.random.default_rng(1)
    flat = (110 + rng.integers(0, 12, (128, 128, 3))).astype(np.uint8)
    out = apply_clahe(flat)
    assert out.shape == flat.shape and out.dtype == np.uint8
    assert out.std() > flat.std()


def test_pipeline_output_contract():
    out = preprocess(Image.fromarray(synthetic_fundus()))
    assert out.shape == (3, INPUT_SIZE, INPUT_SIZE) and out.dtype == np.float32
    assert np.isfinite(out).all()


def test_pipeline_is_deterministic_and_pil_equals_ndarray():
    arr = synthetic_fundus()
    assert np.array_equal(preprocess(arr), preprocess(arr))
    assert np.array_equal(preprocess(arr), preprocess(Image.fromarray(arr)))


def test_custom_size():
    assert preprocess_image(synthetic_fundus(), size=320).shape == (320, 320, 3)


def test_black_image_is_invalid_not_grade_zero():
    with pytest.raises(InvalidFundusImage):
        preprocess(np.zeros((300, 300, 3), dtype=np.uint8))


def test_bad_shapes_and_dtypes_rejected():
    with pytest.raises(InvalidFundusImage):
        preprocess(np.zeros((300, 300), dtype=np.uint8))
    with pytest.raises(InvalidFundusImage):
        preprocess(np.zeros((300, 300, 3), dtype=np.float32))
    with pytest.raises(InvalidFundusImage):
        preprocess(np.full((8, 8, 3), 200, dtype=np.uint8))


def test_non_rgb_pil_is_converted():
    gray = Image.fromarray(synthetic_fundus()).convert("L")
    assert preprocess(gray).shape == (3, INPUT_SIZE, INPUT_SIZE)
