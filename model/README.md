# Modelo

Clasificador experimental de retinopatía diabética (RD) por imagen de fondo de ojo, cinco grados ICDR (0 sin RD, 1 leve, 2 moderada, 3 severa, 4 proliferativa). Es una línea base de referencia para comparar después con DINOv2 y RETFound. No es un sistema clínico validado ni produce diagnóstico.

## Contenido

| Archivo | Descripción |
|---|---|
| `retinazo.py` | Script con las acciones `check`, `prepare`, `train`, `evaluate` y `predict` |
| `requirements.txt` | Dependencias comunes (PyTorch y torchvision se instalan aparte, ver abajo) |

Los directorios `data/`, `splits/` y `runs/` se generan localmente y no se versionan.

## Configuración de la línea base

- EfficientNet-B0 preentrenada en ImageNet, salida de cinco clases.
- Entrada 320 × 320 con relleno para conservar la proporción; normalización ImageNet.
- Aumentos solo en entrenamiento: volteo horizontal, rotación leve, brillo y contraste leves.
- Dos épocas con el extractor congelado y luego ajuste de toda la red con menor tasa de aprendizaje.
- Entropía cruzada ponderada por frecuencia de clase (calculada solo con entrenamiento), AdamW, precisión mixta, parada temprana con paciencia de cinco épocas.
- Selección del checkpoint por kappa cuadrático ponderado (QWK) en validación.
- Semilla fija 42.

## Datos

Dataset APTOS 2019 (Kaggle): se usan `train.csv` y `train_images/`, dispuestos así:

```text
data/aptos/
  train.csv            columnas: id_code, diagnosis
  train_images/*.png
```

`prepare` valida las imágenes y etiquetas, retira copias exactas (hash de píxeles) y genera particiones estratificadas 70/15/15 en `splits/aptos_seed42/`. La separación es por imagen porque el dataset no trae identificadores de paciente; no garantiza independencia entre pacientes ni detecta duplicados aproximados.

## Uso

Requiere Python 3.11 y GPU NVIDIA con CUDA. Desde este directorio:

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe -m pip install torch==2.9.1 torchvision==0.24.1 --index-url https://download.pytorch.org/whl/cu128
.\.venv\Scripts\python.exe -m pip install -r requirements.txt

.\.venv\Scripts\python.exe retinazo.py check
.\.venv\Scripts\python.exe retinazo.py prepare
.\.venv\Scripts\python.exe retinazo.py train --epochs 20 --batch-size 8 --size 320 --run runs/b0_320_seed42
.\.venv\Scripts\python.exe retinazo.py evaluate --run runs/b0_320_seed42 --partition val
.\.venv\Scripts\python.exe retinazo.py predict --run runs/b0_320_seed42 --image ruta\imagen.png
```

`train --smoke` ejecuta una prueba técnica corta con pesos aleatorios; su checkpoint no se puede evaluar ni usar para predecir. Cada corrida exige una carpeta nueva.

## Salidas de una corrida

| Archivo | Contenido |
|---|---|
| `best.pt` | Pesos de la mejor época según QWK de validación |
| `config.json` | Parámetros, versión de PyTorch, dispositivo y pesos por clase |
| `history.json` | Pérdida y métricas por época |
| `train.csv`, `val.csv`, `test.csv` | Particiones usadas, con rutas y hashes |
| `{val,test}_metrics.json` | QWK, macro-F1, accuracy, precisión/recall/F1 por grado, matriz de confusión |
| `{val,test}_predictions.csv` | Etiqueta, predicción y puntuaciones por imagen |

## Protocolo y límites

- La partición `test` se evalúa una sola vez, tras cerrar la selección de modelo con validación.
- Las puntuaciones softmax no están calibradas y no son probabilidades clínicas.
- No hay control de calidad de imagen, agregación por ojo o paciente, ni validación con capturas de smartphone y lente 20D.
