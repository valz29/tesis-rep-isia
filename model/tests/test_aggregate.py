import sys
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from aggregate import (  # noqa: E402
    CONCLUSIVE,
    INCONCLUSIVE,
    ImageResult,
    aggregate_eye,
    aggregate_patient,
)


def imgs(*grades, gradable=True):
    return [ImageResult(g, gradable) for g in grades]


def test_worst_grade_wins_not_average():
    eye = aggregate_eye(imgs(1, 1, 1, 1, 4))
    assert eye.grade == 4 and eye.urgent and eye.referable


def test_single_referable_image_is_conclusive_even_below_min_valid():
    eye = aggregate_eye(imgs(3), min_valid=3)
    assert eye.status == CONCLUSIVE and eye.grade == 3 and eye.urgent


def test_too_few_valid_images_cannot_rule_out():
    eye = aggregate_eye(imgs(0), min_valid=2)
    assert eye.status == INCONCLUSIVE and eye.grade is None


def test_ungradable_and_invalid_outputs_are_excluded():
    images = [ImageResult(4, gradable=False), ImageResult(7), ImageResult(-1), ImageResult(True), ImageResult("2"), ImageResult(1), ImageResult(0)]
    eye = aggregate_eye(images)
    assert eye.n_valid == 2 and eye.n_total == 7 and eye.grade == 1 and eye.status == CONCLUSIVE


def test_no_images_is_inconclusive_never_grade_zero():
    assert aggregate_eye([]).status == INCONCLUSIVE


def test_non_referable_eye_with_enough_images():
    eye = aggregate_eye(imgs(0, 1, 0))
    assert eye.status == CONCLUSIVE and eye.grade == 1 and eye.referable is False


def test_mean_probs_is_auxiliary_only():
    a = ImageResult(0, probs=[1, 0, 0, 0, 0])
    b = ImageResult(1, probs=[0, 1, 0, 0, 0])
    eye = aggregate_eye([a, b])
    assert eye.mean_probs == (0.5, 0.5, 0, 0, 0) and eye.grade == 1


def test_patient_worst_eye():
    od = aggregate_eye(imgs(0, 0))
    oi = aggregate_eye(imgs(2, 1))
    p = aggregate_patient([od, oi])
    assert p.grade == 2 and p.referable and not p.urgent


def test_patient_inconclusive_if_one_eye_unknown_and_other_not_referable():
    p = aggregate_patient([aggregate_eye(imgs(0, 0)), aggregate_eye(imgs(0))])
    assert p.status == INCONCLUSIVE


def test_patient_referable_even_if_other_eye_unknown():
    p = aggregate_patient([aggregate_eye(imgs(3)), aggregate_eye([])])
    assert p.status == CONCLUSIVE and p.grade == 3 and p.urgent


def test_invalid_min_valid():
    with pytest.raises(ValueError):
        aggregate_eye(imgs(0), min_valid=0)


def test_referable_metrics():
    pytest.importorskip("sklearn")
    pytest.importorskip("pandas")
    pytest.importorskip("PIL")
    from retinazo import referable_metrics

    y = [0, 1, 2, 3, 4, 0]
    pred = [0, 2, 2, 1, 4, 0]
    probs = np.eye(5)[pred]
    m = referable_metrics(y, pred, probs)
    assert (m["tp"], m["fn"], m["tn"], m["fp"]) == (2, 1, 2, 1)
    assert m["sensitivity"] == pytest.approx(2 / 3)
    assert m["specificity"] == pytest.approx(2 / 3)
    assert 0 <= m["auc"] <= 1
    only_neg = referable_metrics([0, 1], [0, 0], np.eye(5)[[0, 0]])
    assert only_neg["sensitivity"] is None and only_neg["auc"] is None
