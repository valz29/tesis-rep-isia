import sys
from argparse import Namespace
from pathlib import Path

import numpy as np
import pandas as pd
import pytest
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from retinazo import prepare  # noqa: E402


def build_dataset(root: Path):
    images = root / "train_images"
    images.mkdir(parents=True)
    rng = np.random.default_rng(0)
    rows = []

    def add(name, label, array):
        Image.fromarray(array).save(images / f"{name}.png")
        rows.append((name, label))

    for label in range(5):
        for i in range(12):
            add(f"u{label}_{i}", label, rng.integers(0, 255, (16, 16, 3), dtype=np.uint8))
    same = rng.integers(0, 255, (16, 16, 3), dtype=np.uint8)
    add("dup_a", 0, same)
    add("dup_b", 0, same)  # copia exacta, misma etiqueta
    clash = rng.integers(0, 255, (16, 16, 3), dtype=np.uint8)
    add("clash_a", 2, clash)
    add("clash_b", 4, clash)  # misma imagen, etiqueta distinta
    pd.DataFrame(rows, columns=["id_code", "diagnosis"]).to_csv(root / "train.csv", index=False)


def args(root, drop):
    return Namespace(data=root, splits=root.parent / "splits", seed=42, drop_conflicts=drop)


def test_conflicts_stop_without_flag(tmp_path):
    root = tmp_path / "aptos"
    build_dataset(root)
    with pytest.raises(ValueError, match="drop-conflicts"):
        prepare(args(root, False))
    assert not (tmp_path / "splits").exists()


def test_conflicts_excluded_and_logged(tmp_path):
    root = tmp_path / "aptos"
    build_dataset(root)
    prepare(args(root, True))
    out = tmp_path / "splits"
    kept = pd.concat(pd.read_csv(out / f"{n}.csv") for n in ("train", "val", "test"))
    conflicts = pd.read_csv(out / "conflictos_etiqueta_excluidos.csv")
    assert set(conflicts.id_code) == {"clash_a", "clash_b"}
    assert not kept.id_code.isin(conflicts.id_code).any()
    assert kept.sha256_pixels.is_unique  # copias exactas retiradas
    assert len(kept) == 60 + 1  # 60 unicas + 1 de la pareja duplicada
