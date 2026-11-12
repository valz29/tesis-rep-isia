import json
import sys
from argparse import Namespace
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

torch = pytest.importorskip("torch")
pytest.importorskip("torchvision")
pytest.importorskip("onnx")
pytest.importorskip("onnxruntime")

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import retinazo  # noqa: E402

SIZE = 64


@pytest.fixture(scope="module")
def exported(tmp_path_factory):
    run = tmp_path_factory.mktemp("run")
    torch.manual_seed(0)
    network = retinazo.model(False)  # pesos aleatorios: solo prueba tecnica del formato
    torch.save({"state_dict": network.state_dict(), "size": SIZE, "epoch": 1, "qwk": 0.0, "smoke": False}, run / "best.pt")
    args = Namespace(run=run, onnx=None, allow_cpu=True)
    retinazo.export(args)
    return run, network


def test_export_creates_onnx_and_metadata(exported):
    run, _ = exported
    info = json.loads((run / "model.json").read_text(encoding="utf-8"))
    assert (run / "model.onnx").exists() and info["size_mb"] > 0
    assert info["max_abs_diff_vs_pytorch"] < 1e-3
    assert info["output"]["shape"] == ["batch", 5] and info["cpu_ms_per_image"] > 0


def test_export_refuses_to_overwrite(exported):
    run, _ = exported
    with pytest.raises(ValueError, match="ya existe"):
        retinazo.export(Namespace(run=run, onnx=None, allow_cpu=True))


def test_onnx_supports_batches_and_returns_softmax(exported):
    run, _ = exported
    session = retinazo.onnx_session(run / "model.onnx", gpu=False)
    out = session.run(None, {"image": np.zeros((3, 3, SIZE, SIZE), dtype=np.float32)})[0]
    assert out.shape == (3, 5) and np.allclose(out.sum(axis=1), 1, atol=1e-5)


def test_numpy_input_matches_torch_transform(exported):
    image = Image.fromarray(np.random.default_rng(1).integers(0, 255, (50, 80, 3), dtype=np.uint8))
    expected = retinazo.transform(SIZE)(image).unsqueeze(0).numpy()
    assert np.allclose(retinazo.onnx_input(image, SIZE), expected, atol=1e-5)


def test_onnx_matches_pytorch_on_real_input(exported):
    run, network = exported
    image = Image.fromarray(np.random.default_rng(2).integers(0, 255, (60, 60, 3), dtype=np.uint8))
    x = retinazo.onnx_input(image, SIZE)
    session = retinazo.onnx_session(run / "model.onnx", gpu=False)
    got = session.run(None, {"image": x})[0]
    with torch.inference_mode():
        expected = network.eval()(torch.from_numpy(x)).softmax(1).numpy()
    assert np.allclose(got, expected, atol=1e-4)
