import pickle
import sys
from argparse import Namespace
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from retinazo import PadToSquare, loader_options  # noqa: E402


def test_pad_transform_is_picklable_and_pads_to_square():
    pad = pickle.loads(pickle.dumps(PadToSquare(64)))  # los workers de Windows serializan el dataset
    out = pad(Image.new("RGB", (100, 50), (200, 100, 50)))
    assert out.size == (64, 64)


def test_loader_options():
    assert loader_options(Namespace(workers=0)) == {"num_workers": 0, "persistent_workers": False}
    assert loader_options(Namespace(workers=3)) == {"num_workers": 3, "persistent_workers": True}
