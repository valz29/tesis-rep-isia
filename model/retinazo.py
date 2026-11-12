"""Primer experimento APTOS por imagen. No es un sistema clinico validado."""
from __future__ import annotations

import argparse
import hashlib
import json
import random
from pathlib import Path

import numpy as np
import pandas as pd
from PIL import Image, ImageOps
from sklearn.metrics import accuracy_score, classification_report, cohen_kappa_score, confusion_matrix, f1_score, roc_auc_score
from sklearn.model_selection import train_test_split

LABELS = list(range(5))


def save_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False), encoding="utf-8")


def prepare(args):
    root = args.data.resolve()
    output = args.splits
    if output.exists():
        raise ValueError("La carpeta de particiones ya existe. Conserva las particiones o usa otra ruta.")
    df = pd.read_csv(root / "train.csv", dtype={"id_code": str})
    if not {"id_code", "diagnosis"}.issubset(df.columns):
        raise ValueError("Se requieren id_code y diagnosis en train.csv.")
    if df.id_code.duplicated().any() or not df.diagnosis.isin(LABELS).all():
        raise ValueError("IDs repetidos o etiquetas fuera de 0..4.")
    records = []
    for row in df.itertuples():
        path = root / "train_images" / (row.id_code + ".png")
        with Image.open(path) as image:
            image = ImageOps.exif_transpose(image).convert("RGB")
            image.load()
            digest = hashlib.sha256(str(image.size).encode() + image.tobytes()).hexdigest()
        records.append({"id_code": row.id_code, "path": str(path), "diagnosis": int(row.diagnosis), "sha256_pixels": digest})
    data = pd.DataFrame(records)
    conflicting = data.groupby("sha256_pixels").diagnosis.transform("nunique") > 1
    conflicts = data[conflicting]
    if conflicting.any():
        if not args.drop_conflicts:
            raise ValueError("Hay imagenes identicas con etiquetas distintas. Revisalas o usa --drop-conflicts para excluir todos los miembros de esos grupos.")
        # Se excluyen TODAS las imagenes del grupo: no se elige una etiqueta ni se usa el modelo para decidir.
        data = data[~conflicting].reset_index(drop=True)
    # Retirar copias exactas ANTES de dividir. No detecta versiones recortadas o similares.
    duplicates = data[data.duplicated("sha256_pixels", keep="first")]
    data = data.drop_duplicates("sha256_pixels").reset_index(drop=True)
    train, rest = train_test_split(data, test_size=0.30, stratify=data.diagnosis, random_state=args.seed)
    val, test = train_test_split(rest, test_size=0.50, stratify=rest.diagnosis, random_state=args.seed)
    output.mkdir(parents=True)
    duplicates.to_csv(output / "duplicados_exactos_retirados.csv", index=False)
    conflicts.to_csv(output / "conflictos_etiqueta_excluidos.csv", index=False)
    for name, frame in [("train", train), ("val", val), ("test", test)]:
        frame.to_csv(output / (name + ".csv"), index=False)
        print(name, len(frame), frame.diagnosis.value_counts().sort_index().to_dict())
    save_json(output / "protocolo.json", {"seed": args.seed, "proportions": [0.70, 0.15, 0.15], "unit": "image", "exact_duplicates_removed": len(duplicates), "label_conflict_images_excluded": len(conflicts), "warning": "Sin IDs de pacientes: no garantiza independencia por paciente. No es validacion local de 20D. Revisar duplicados aproximados."})


def metrics(y, pred):
    kappa = cohen_kappa_score(y, pred, labels=LABELS, weights="quadratic")
    return {"accuracy": float(accuracy_score(y, pred)), "macro_f1": float(f1_score(y, pred, labels=LABELS, average="macro", zero_division=0)), "qwk": float(kappa) if np.isfinite(kappa) else None, "report": classification_report(y, pred, labels=LABELS, output_dict=True, zero_division=0), "confusion_matrix": confusion_matrix(y, pred, labels=LABELS).tolist()}


REFERABLE_GRADE = 2  # RD referible: grado >= 2 (moderada o peor).


def referable_metrics(y, pred, probs=None):
    """Sensibilidad, especificidad y AUC para RD referible (grado >= 2).

    Sensibilidad/especificidad usan la clase predicha (sin umbral ajustado).
    AUC usa la suma de probabilidades softmax de los grados >= 2 (puntuacion, no probabilidad calibrada).
    Valores indefinidos (sin positivos o sin negativos) se devuelven como None.
    """
    y_true = np.asarray(y) >= REFERABLE_GRADE
    y_pred = np.asarray(pred) >= REFERABLE_GRADE
    tp = int(np.sum(y_true & y_pred))
    fn = int(np.sum(y_true & ~y_pred))
    tn = int(np.sum(~y_true & ~y_pred))
    fp = int(np.sum(~y_true & y_pred))
    result = {"threshold_grade": REFERABLE_GRADE, "tp": tp, "fn": fn, "tn": tn, "fp": fp,
              "sensitivity": tp / (tp + fn) if tp + fn else None,
              "specificity": tn / (tn + fp) if tn + fp else None,
              "auc": None}
    if probs is not None and 0 < y_true.sum() < len(y_true):
        score = np.asarray(probs, dtype=float)[:, REFERABLE_GRADE:].sum(axis=1)
        result["auc"] = float(roc_auc_score(y_true, score))
    return result


class PadToSquare:
    """Ajusta la imagen a size x size con relleno negro. Clase (no lambda) para poder usar workers en Windows."""

    def __init__(self, size):
        self.size = size

    def __call__(self, image):
        return ImageOps.pad(image, (self.size, self.size), method=Image.Resampling.BILINEAR, color=(0, 0, 0))


def transform(size, training=False):
    from torchvision import transforms as T
    # Conservar todo el encuadre y la proporcion; no aplicar recorte central.
    operations = [PadToSquare(size)]
    if training:
        operations += [T.RandomHorizontalFlip(), T.RandomRotation(10), T.ColorJitter(brightness=0.1, contrast=0.1)]
    return T.Compose(operations + [T.ToTensor(), T.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])])


class Images:
    def __init__(self, frame, size, training=False):
        self.frame = frame.reset_index(drop=True)
        self.transform = transform(size, training)

    def __len__(self):
        return len(self.frame)

    def __getitem__(self, index):
        row = self.frame.iloc[index]
        with Image.open(row.path) as image:
            image = ImageOps.exif_transpose(image).convert("RGB")
            tensor = self.transform(image)
        return tensor, int(row.diagnosis)


def model(pretrained):
    import torch
    from torchvision.models import efficientnet_b0, EfficientNet_B0_Weights
    network = efficientnet_b0(weights=EfficientNet_B0_Weights.IMAGENET1K_V1 if pretrained else None)
    network.classifier[1] = torch.nn.Linear(network.classifier[1].in_features, 5)
    return network


def loader_options(args):
    # workers=0 (por defecto) es lo mas simple en Windows; --workers 2-4 acelera la lectura de PNG grandes.
    return {"num_workers": args.workers, "persistent_workers": args.workers > 0}


def device_for(args):
    import torch
    if not torch.cuda.is_available() and not args.allow_cpu:
        raise RuntimeError("CUDA no disponible. Ejecuta check. CPU solo para pruebas: --allow-cpu.")
    return torch.device("cuda" if torch.cuda.is_available() else "cpu")


def run_epoch(network, loader, device, criterion=None, optimizer=None, scaler=None, freeze=False, limit=0):
    import torch
    from tqdm import tqdm
    training = optimizer is not None
    network.train(training)
    if training and freeze:
        network.features.eval()  # No cambiar BatchNorm durante la fase congelada.
    ys, predictions, probabilities = [], [], []
    total_loss, count = 0.0, 0
    for step, (x, y) in enumerate(tqdm(loader, leave=False)):
        if limit and step >= limit:
            break
        x, y = x.to(device), y.to(device)
        if training:
            optimizer.zero_grad(set_to_none=True)
        with torch.set_grad_enabled(training), torch.autocast(device_type=device.type, enabled=device.type == "cuda"):
            logits = network(x)
            loss = criterion(logits, y) if criterion is not None else None
        if training:
            scaler.scale(loss).backward()
            scaler.step(optimizer)
            scaler.update()
        if loss is not None:
            total_loss += loss.item() * len(y)
        count += len(y)
        ys.extend(y.cpu().tolist())
        predictions.extend(logits.argmax(1).detach().cpu().tolist())
        probabilities.extend(logits.float().softmax(1).detach().cpu().tolist())
    result = metrics(ys, predictions)
    result["referable"] = referable_metrics(ys, predictions, probabilities)
    result["loss"] = total_loss / count if criterion is not None else None
    return result, ys, predictions, probabilities


def train(args):
    import torch
    if args.epochs < 1 or args.batch_size < 1 or args.size < 32:
        raise ValueError("epochs y batch-size deben ser positivos; size >=32.")
    device = device_for(args)
    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    torch.backends.cudnn.benchmark = False
    torch.backends.cudnn.deterministic = True
    if args.run.exists():
        raise ValueError("La carpeta de corrida ya existe. Usa --run con un nombre nuevo.")
    tr = pd.read_csv(args.splits / "train.csv")
    va = pd.read_csv(args.splits / "val.csv")
    if set(tr.diagnosis) != set(LABELS):
        raise ValueError("Faltan clases en entrenamiento.")
    args.run.mkdir(parents=True)
    for name in ("train", "val", "test"):
        source = args.splits / (name + ".csv")
        (args.run / source.name).write_bytes(source.read_bytes())
    from torch.utils.data import DataLoader
    generator = torch.Generator().manual_seed(args.seed)
    train_loader = DataLoader(Images(tr, args.size, True), batch_size=args.batch_size, shuffle=True, generator=generator, **loader_options(args))
    val_loader = DataLoader(Images(va, args.size), batch_size=args.batch_size, **loader_options(args))
    network = model(not args.smoke).to(device)
    counts = np.bincount(tr.diagnosis.to_numpy(), minlength=5)
    weights = torch.tensor(len(tr) / (5 * counts), dtype=torch.float32, device=device)
    criterion = torch.nn.CrossEntropyLoss(weight=weights)
    scaler = torch.amp.GradScaler("cuda", enabled=device.type == "cuda")
    config = {k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()}
    config.update({"torch": torch.__version__, "device": str(device), "seed": args.seed, "pretrained": not args.smoke, "unit": "image", "class_weights": weights.cpu().tolist()})
    save_json(args.run / "config.json", config)
    best, stale, history, optimizer = -float("inf"), 0, [], None
    for epoch in range(args.epochs):
        frozen = epoch < args.warmup
        if epoch == 0 or epoch == args.warmup:
            for parameter in network.features.parameters():
                parameter.requires_grad = not frozen
            optimizer = torch.optim.AdamW([
                {"params": [p for p in network.features.parameters() if p.requires_grad], "lr": 1e-4},
                {"params": network.classifier.parameters(), "lr": 1e-3 if frozen else 3e-4},
            ], weight_decay=1e-4)
        limit = 2 if args.smoke else 0
        train_result, *_ = run_epoch(network, train_loader, device, criterion, optimizer, scaler, frozen, limit)
        val_result, *_ = run_epoch(network, val_loader, device, criterion, limit=limit)
        history.append({"epoch": epoch + 1, "frozen": frozen, "train": train_result, "val": val_result})
        save_json(args.run / "history.json", history)
        print(f"Epoch {epoch+1}: val QWK={val_result['qwk']} macro-F1={val_result['macro_f1']:.4f}", flush=True)
        score = val_result["qwk"]
        score = score if score is not None else -1.0
        if score > best:
            best, stale = score, 0
            torch.save({"state_dict": network.state_dict(), "size": args.size, "epoch": epoch + 1, "qwk": score, "smoke": args.smoke}, args.run / "best.pt")
        else:
            stale += 1
        if stale >= args.patience and epoch >= args.warmup:
            print("Parada temprana.")
            break
    print("Modelo guardado en", args.run / "best.pt")
    if args.export_onnx and not args.smoke:
        export(args)


def load(args, cpu=False):
    import torch
    device = torch.device("cpu") if cpu else device_for(args)
    checkpoint = torch.load(args.run / "best.pt", map_location="cpu", weights_only=True)
    if checkpoint.get("smoke"):
        raise ValueError("Esta corrida es una prueba tecnica sin pesos preentrenados. No usar para evaluar o predecir.")
    network = model(False)
    network.load_state_dict(checkpoint["state_dict"])
    network.to(device).eval()
    return network, checkpoint["size"], device


def evaluate(args):
    import torch
    network, size, device = load(args)
    frame = pd.read_csv(args.run / (args.partition + ".csv"))
    result, _, pred, probs = run_epoch(network, torch.utils.data.DataLoader(Images(frame, size), batch_size=args.batch_size, **loader_options(args)), device)
    save_json(args.run / (args.partition + "_metrics.json"), result)
    frame["prediction"] = pred
    for degree in LABELS:
        frame["p" + str(degree)] = np.asarray(probs)[:, degree]
    frame.to_csv(args.run / (args.partition + "_predictions.csv"), index=False)
    print(json.dumps(result, indent=2))


IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
IMAGENET_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)
ONNX_OPSET = 17


def onnx_input(image, size):
    """Entrada del ONNX en numpy (sin torch): mismo relleno y normalizacion que transform(size) sin aumentos."""
    padded = PadToSquare(size)(ImageOps.exif_transpose(image).convert("RGB"))
    scaled = (np.asarray(padded, dtype=np.float32) / 255.0 - IMAGENET_MEAN) / IMAGENET_STD
    return np.ascontiguousarray(scaled.transpose(2, 0, 1)[None], dtype=np.float32)


def onnx_session(path, gpu=True):
    """Sesion de ONNX Runtime. Usa CUDA si esta disponible (paquete onnxruntime-gpu); si no, CPU."""
    import onnxruntime
    if gpu and hasattr(onnxruntime, "preload_dlls"):
        try:
            onnxruntime.preload_dlls()  # reutiliza las DLL de CUDA/cuDNN que trae PyTorch
        except Exception:
            pass
    providers = [p for p in ("CUDAExecutionProvider", "CPUExecutionProvider") if p in onnxruntime.get_available_providers() and (gpu or p == "CPUExecutionProvider")]
    return onnxruntime.InferenceSession(str(path), providers=providers)


def time_session(session, sample, runs=20):
    import time
    session.run(None, {"image": sample})  # calentamiento
    start = time.perf_counter()
    for _ in range(runs):
        session.run(None, {"image": sample})
    return round((time.perf_counter() - start) / runs * 1000, 1)


def export(args):
    """Exporta best.pt a ONNX (salida: 5 puntuaciones softmax, no calibradas) y verifica contra PyTorch."""
    import onnxruntime
    import torch
    network, size, _ = load(args, cpu=True)

    class WithSoftmax(torch.nn.Module):
        def __init__(self, inner):
            super().__init__()
            self.inner = inner

        def forward(self, x):
            return self.inner(x).softmax(1)

    wrapped = WithSoftmax(network).eval()
    path = args.onnx or args.run / "model.onnx"
    if path.exists():
        raise ValueError("El archivo ONNX ya existe. Usa --onnx con otro nombre.")
    dummy = torch.zeros(1, 3, size, size)
    torch.onnx.export(wrapped, dummy, str(path), input_names=["image"], output_names=["scores"], dynamic_axes={"image": {0: "batch"}, "scores": {0: "batch"}}, opset_version=ONNX_OPSET, dynamo=False)
    session = onnx_session(path, gpu=False)  # la verificacion de equivalencia se hace en CPU
    sample = np.random.default_rng(0).normal(size=(2, 3, size, size)).astype(np.float32)
    with torch.inference_mode():
        expected = wrapped(torch.from_numpy(sample)).numpy()
    got = session.run(None, {"image": sample})[0]
    max_diff = float(np.abs(expected - got).max())
    if max_diff > 1e-3:
        path.unlink()
        raise RuntimeError(f"El ONNX no coincide con PyTorch (diferencia maxima {max_diff:.2e}). Exportacion descartada.")
    one = sample[:1]
    cpu_ms = time_session(session, one)
    gpu_session = onnx_session(path)
    gpu_ms = time_session(gpu_session, one) if gpu_session.get_providers()[0] == "CUDAExecutionProvider" else None
    checkpoint_info = torch.load(args.run / "best.pt", map_location="cpu", weights_only=True)
    info = {
        "file": path.name, "size_mb": round(path.stat().st_size / 1024**2, 2), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "input": {"name": "image", "shape": ["batch", 3, size, size], "dtype": "float32", "channels": "RGB", "pad_to_square": "negro, bilineal", "mean": IMAGENET_MEAN.tolist(), "std": IMAGENET_STD.tolist()},
        "output": {"name": "scores", "shape": ["batch", 5], "meaning": "softmax grados ICDR 0-4; no son probabilidades calibradas"},
        "onnx_opset": ONNX_OPSET, "max_abs_diff_vs_pytorch": max_diff, "cpu_ms_per_image": cpu_ms, "gpu_ms_per_image": gpu_ms, "providers_available": onnxruntime.get_available_providers(),
        "checkpoint_epoch": checkpoint_info.get("epoch"), "checkpoint_val_qwk": checkpoint_info.get("qwk"),
        "torch": torch.__version__, "onnxruntime": onnxruntime.__version__,
        "warning": "Experimental. No es diagnostico ni esta validado clinicamente.",
    }
    save_json(path.with_suffix(".json"), info)
    print(json.dumps(info, indent=2))


def predict_onnx(args):
    session = onnx_session(args.onnx)
    size = session.get_inputs()[0].shape[2]
    with Image.open(args.image) as image:
        probs = session.run(None, {"image": onnx_input(image, size)})[0][0].tolist()
    print(json.dumps({"experimental_image_prediction": int(np.argmax(probs)), "scores_not_calibrated": probs, "provider": session.get_providers()[0], "warning": "Sin control de calidad ni validacion clinica o de captura 20D."}, indent=2))


def predict(args):
    if args.onnx:
        return predict_onnx(args)
    import torch
    network, size, device = load(args)
    with Image.open(args.image) as image:
        x = transform(size)(ImageOps.exif_transpose(image).convert("RGB")).unsqueeze(0).to(device)
    with torch.inference_mode():
        probs = network(x).softmax(1)[0].cpu().tolist()
    print(json.dumps({"experimental_image_prediction": int(np.argmax(probs)), "scores_not_calibrated": probs, "warning": "Sin control de calidad ni validacion clinica o de captura 20D."}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["check", "prepare", "train", "evaluate", "predict", "export"])
    parser.add_argument("--data", type=Path, default=Path("data/aptos"))
    parser.add_argument("--splits", type=Path, default=Path("splits/aptos_seed42"))
    parser.add_argument("--run", type=Path, default=Path("runs/b0_320_seed42"))
    parser.add_argument("--seed", type=int, default=42, help="Semilla de particiones (prepare) y de entrenamiento (train). Las particiones deben ser las mismas para comparar modelos.")
    parser.add_argument("--size", type=int, default=320)
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--workers", type=int, default=0, help="Procesos para leer imagenes (0 = proceso principal).")
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--warmup", type=int, default=2)
    parser.add_argument("--patience", type=int, default=5)
    parser.add_argument("--partition", choices=["val", "test"], default="val")
    parser.add_argument("--image", type=Path)
    parser.add_argument("--drop-conflicts", action="store_true", help="prepare: excluir imagenes identicas con etiquetas contradictorias (se registran en conflictos_etiqueta_excluidos.csv).")
    parser.add_argument("--onnx", type=Path, help="export: ruta de salida (por defecto <run>/model.onnx). predict: usar este ONNX en vez de best.pt.")
    parser.add_argument("--export-onnx", action="store_true", help="train: exportar a ONNX al terminar.")
    parser.add_argument("--allow-cpu", action="store_true")
    parser.add_argument("--smoke", action="store_true", help="Dos lotes por fase; pesos aleatorios, solo prueba tecnica.")
    args = parser.parse_args()
    if args.action == "check":
        import torch
        import torchvision
        print("torch", torch.__version__, "torchvision", torchvision.__version__)
        print("CUDA disponible:", torch.cuda.is_available())
        if torch.cuda.is_available():
            print(torch.cuda.get_device_name(0))
            print("VRAM GB:", round(torch.cuda.get_device_properties(0).total_memory / 1024**3, 2))
            print("Operacion CUDA:", (torch.ones(2, device="cuda") * 2).cpu().tolist())
    else:
        if args.action == "predict" and args.image is None:
            parser.error("predict requiere --image")
        globals()[args.action](args)


if __name__ == "__main__":
    main()
