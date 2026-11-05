# Primer entrenamiento de Retinazo

Fecha: 2 de noviembre de 2026. Ejecutar en la laptop con RTX 4060 de 8 GB.

Objetivo: obtener un primer clasificador experimental por imagen de cinco grados con EfficientNet-B0 preentrenada en ImageNet. Es la primera referencia para comparar despues con DINOv2 y RETFound. Todavia no combina campos ni determina la calidad de una captura.

## 1. Llevar estos archivos a la laptop

Clona o copia el repositorio en la laptop y abre la carpeta `model/` en VS Code con una terminal PowerShell. Los comandos siguientes se ejecutan desde `model/`:

```powershell
cd <ruta-del-repo>\model
nvidia-smi
py -0p
```

La GPU debe ser RTX 4060 Laptop y su memoria aproximadamente 8192 MiB. Si aparece GTX 1050, estas en el equipo diferente al previsto. Conecta el cargador durante el entrenamiento.

El entorno inspeccionado al elaborar la guia tiene Python 3.11 instalado, pero `python` apunta a Python 3.9 y no tiene PyTorch. Por eso usamos explicitamente `py -3.11` y un entorno separado. No necesitas cambiar el Python global ni configurar Conda.

Si `py -3.11 --version` no funciona en la laptop, instala Python 3.11 desde https://www.python.org/downloads/windows/ con el lanzador de Python y vuelve a abrir la terminal. No reemplaces los comandos por el Python 3.9 global.

## 2. Crear el entorno e instalar dependencias

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install torch==2.9.1 torchvision==0.24.1 --index-url https://download.pytorch.org/whl/cu128
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m pip freeze > entorno_instalado.txt
.\.venv\Scripts\python.exe retinazo.py check
```

Se fija una pareja publicada y compatible de PyTorch/torchvision para reproducir este experimento; no se afirma que sea la version mas reciente. Fuente: https://pytorch.org/get-started/previous-versions/ . Los paquetes CUDA requieren un controlador NVIDIA compatible. Si la comprobacion falla, conserva el mensaje completo y la salida de `nvidia-smi` antes de continuar. No hace falta instalar todo CUDA Toolkit para utilizar estas ruedas precompiladas.

Resultado esperado: CUDA disponible True, RTX 4060, unos 8 GB y operacion CUDA [2.0, 2.0]. No ejecutes el entrenamiento largo hasta tenerlo. Estos comandos no requieren activar el entorno y evitan problemas con ExecutionPolicy.

## 3. Descargar APTOS desde su fuente

Abre https://www.kaggle.com/competitions/aptos2019-blindness-detection/data . Inicia sesion y acepta las reglas si Kaggle lo pide. Descarga y extrae los archivos. Para este experimento solo necesitamos `train.csv` y la carpeta `train_images`, que contiene imagenes PNG etiquetadas. No uses `test_images` de Kaggle para calcular metricas: no disponemos de sus etiquetas oficiales en este flujo.

La estructura debe quedar asi, sin otra carpeta intermedia:

```text
model/
  retinazo.py
  requirements.txt
  GUIA.md
  data/
    aptos/
      train.csv
      train_images/
        000c1434d8d7.png
        ...
```

Comprueba que el CSV contiene columnas `id_code` y `diagnosis`. Grados: 0 sin RD, 1 leve, 2 moderada, 3 severa, 4 proliferativa, conforme a las etiquetas de este dataset. No cambies etiquetas basandote en la prediccion del modelo.

## 4. Revisar y separar los datos una sola vez

```powershell
.\.venv\Scripts\python.exe retinazo.py prepare --drop-conflicts
```

APTOS contiene imagenes identicas con etiquetas distintas (30 grupos, unas 65 imagenes). Sin `--drop-conflicts` el script se detiene. Con la opcion se excluyen todas las imagenes de esos grupos y se registran en `conflictos_etiqueta_excluidos.csv`; no se elige ninguna etiqueta. El script abre todas las imagenes, detecta archivos ausentes o ilegibles, comprueba etiquetas, identifica imagenes con pixeles RGB identicos y retira copias exactas. Si una imagen identica tiene etiquetas contradictorias, se detiene para revision. Genera `splits/aptos_seed42/train.csv`, `val.csv`, `test.csv`, un registro de duplicados retirados y un protocolo.

Divide aproximadamente 70% entrenamiento, 15% validacion y 15% prueba, con estratificacion por grado y semilla 42. No copies manualmente archivos entre particiones. Conserva esos CSV para comparar todos los modelos.

**Limite del experimento:** esta separacion es por imagen, porque este flujo de APTOS no tiene identificadores fiables de paciente. No garantiza que pacientes distintos queden separados. El hash tampoco detecta recortes, compresiones o fotos casi identicas. Antes de reportar resultados formales, revisar duplicados aproximados y usar datos con identificacion de paciente y una prueba local independiente. La validacion local no debe usarse para elegir el modelo.

Revisa visualmente ejemplos de los cinco grados, resolucion y encuadres. Una mala imagen no debe convertirse en grado 0. Este primer script no resuelve la graduabilidad.

## 5. Prueba tecnica corta

```powershell
.\.venv\Scripts\python.exe retinazo.py train --smoke --epochs 1 --run runs/smoke_01
```

Procesa dos lotes de entrenamiento y dos de validacion con pesos aleatorios. Solo comprueba memoria y ejecucion. Sus metricas no tienen valor de rendimiento y el script impide usar ese checkpoint para evaluar o predecir. Si agota memoria, repite con `--batch-size 4` y un nombre nuevo, por ejemplo `--run runs/smoke_02`.

## 6. Primer entrenamiento real

```powershell
.\.venv\Scripts\python.exe retinazo.py train --epochs 20 --batch-size 8 --size 320 --run runs/b0_320_seed42
```

La primera ejecucion real descarga los pesos de ImageNet desde PyTorch y necesita internet. Configuracion inicial, pendiente de medir en tu laptop:

- EfficientNet-B0 con salida de cinco clases.
- Imagen completa ajustada a 320 x 320 con relleno para conservar proporcion; sin recorte central.
- Normalizacion ImageNet; volteos horizontales, rotaciones leves y cambios leves de brillo/contraste solo en entrenamiento.
- Dos epocas entrenando el clasificador con extractor congelado; despues ajuste de toda la red con menor tasa de aprendizaje.
- Entropia cruzada con pesos calculados solo del conjunto de entrenamiento para el desbalance.
- Precision mixta en GPU, lote de 8, maximo 20 epocas y parada tras cinco sin mejorar, despues del calentamiento.
- Seleccion de checkpoint por kappa cuadratico ponderado (QWK) de validacion. No consulta prueba durante entrenamiento.

Si aparece `CUDA out of memory`, cierra otros procesos que usen GPU y repite con lote 4, conservando resolucion y particiones, en otra carpeta: `--run runs/b0_320_bs4_seed42`. No reutilices una carpeta de corrida existente. El programa rechaza sobreescrituras. Si se interrumpe, conserva la corrida; este primer script no reanuda el optimizador.

No estimamos duracion sin medir las primeras epocas. Semillas y configuracion quedan registradas, pero no se garantiza identidad numerica entre equipos/versiones.

## 7. Revisar validacion y errores

```powershell
.\.venv\Scripts\python.exe retinazo.py evaluate --run runs/b0_320_seed42 --partition val
```

Archivos principales en esa corrida:

| Archivo | Contenido |
|---|---|
| best.pt | Pesos de la mejor epoca segun QWK de validacion |
| config.json | Parametros, version de PyTorch, dispositivo y pesos por clase |
| history.json | Perdida y metricas de entrenamiento/validacion por epoca |
| train.csv, val.csv, test.csv | Particiones utilizadas, con rutas y hashes |
| val_metrics.json | QWK, macro-F1, accuracy, precision/recall/F1 por grado y matriz de confusion |
| val_predictions.csv | Etiqueta, prediccion y puntuaciones por imagen |

En la matriz de confusion las filas son grado real y las columnas grado predicho, en orden 0 a 4. El recall de cada clase expresa la sensibilidad para ese grado. Revisa especialmente errores entre grados alejados y el rendimiento en clases con pocos ejemplos. Compara contra predecir siempre el grado mas frecuente: la accuracy sola puede enganar.

No hay una cifra unica de aprobacion clinica para este ejercicio. No interpretes las puntuaciones softmax como probabilidades clinicas calibradas. Este programa no realiza calibracion ni calcula intervalos de confianza.

## 8. Prueba reservada, cuando cierres la comparacion

Mientras estes modificando el modelo usa validacion. Cuando hayas seleccionado configuracion/modelo y cerrado los ajustes, ejecuta:

```powershell
.\.venv\Scripts\python.exe retinazo.py evaluate --run runs/b0_320_seed42 --partition test
```

Genera `test_metrics.json` y `test_predictions.csv`. No uses ese resultado para volver a ajustar hiperparametros y seguir presentandolo como prueba independiente. La comparacion de EfficientNet, DINOv2 y RETFound debe decidirse con validacion antes de abrir esta prueba. Este comando no impide tecnicamente consultar prueba varias veces: el protocolo depende de respetar esa reserva.

## 9. Probar una fotografia individual

```powershell
.\.venv\Scripts\python.exe retinazo.py predict --run runs/b0_320_seed42 --image "C:\ruta\fotografia.png"
```

Devuelve una clasificacion experimental y cinco puntuaciones. No comprueba calidad/cobertura ni integra otras vistas. Una prediccion en una captura de celular no demuestra generalizacion y no debe presentarse como diagnostico.

## 10. Siguientes experimentos

Con el primer entrenamiento completo, revisaremos `config.json`, `history.json` y `val_metrics.json` para decidir el siguiente paso. Cambiar una cosa por experimento: resolucion mayor, DINOv2 congelado con clasificador, RETFound congelado, despues ajuste parcial del candidato mas prometedor. Mantener particiones y protocolo para compararlos.

En paralelo: definir con el especialista los campos y condiciones de captura; hacer el piloto real; almacenar paciente/visita/ojo/campo, calidad y referencia clinica; mantener todas las imagenes de un paciente en la misma particion. Para combinar vistas necesitamos fotos realmente agrupadas por ojo y una referencia por ojo; no formar grupos artificiales de imagenes de pacientes diferentes. Reservar pacientes locales para una prueba final separada de los usados para adaptacion.

## Verificacion realizada al preparar estos archivos

Se reviso sintaxis y se verifico la preparacion de particiones con un conjunto sintetico, incluidos duplicados y etiquetas contradictorias. Las metricas de RD referible y `aggregate.py` se probaron con pytest sobre datos sinteticos, sin PyTorch. No se instalo PyTorch, no se descargo APTOS y no se ejecuto entrenamiento real en el equipo de revision. Los pasos 2, 5 y 6 verifican las dependencias y la ejecucion efectiva en tu RTX 4060.

## Fuentes

- Datos y reglas APTOS: https://www.kaggle.com/competitions/aptos2019-blindness-detection/data
- Parejas oficiales PyTorch/torchvision y CUDA: https://pytorch.org/get-started/previous-versions/
- Arquitectura y pesos EfficientNet-B0: https://docs.pytorch.org/vision/stable/models/generated/torchvision.models.efficientnet_b0.html
