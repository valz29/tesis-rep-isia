# Retinazo · servicio de imágenes

**Desplegado el 5 de noviembre de 2026.** Supabase mantiene Auth y PostgreSQL; Cloudflare R2 guarda las imágenes. FastAPI funciona en Render Free en `https://retinazo-images.onrender.com`, región Virginia, sin depender de la computadora de desarrollo. El modelo todavía no se ejecuta.

Se comprobó el recorrido remoto con cuentas, pacientes y PNG sintéticos: carga de tres archivos, reintento idempotente, persistencia, descarga firmada con igualdad de bytes y autorización de profesional/administrador. Todos los registros, cuentas y objetos sintéticos se eliminaron. El teléfono físico y la calidad clínica de las imágenes requieren validación aparte.

## Estructura

- `domain/`: entidades y contratos del almacenamiento, identidad, evaluación e inspección.
- `application/`: reglas de carga y consulta, sin FastAPI, boto3, HTTP o Pillow.
- `infrastructure/`: Supabase por HTTP, R2 mediante el SDK S3 y verificación de imágenes con Pillow.
- `presentation/`: rutas FastAPI y autenticación HTTP.
- `main.py`: inyección, ciclo de vida y límite de petición.

## Configuración exclusiva del servidor

Copia `.env.example` a `.env` para desarrollo o configura esas variables como secretos del servicio en Render. No las envíes al APK ni las subas a Git.

| Variable | Uso |
|---|---|
| `SUPABASE_URL` | Origen HTTPS del proyecto |
| `SUPABASE_PUBLISHABLE_KEY` | Acceso a Auth y consultas bajo RLS |
| `SUPABASE_SERVICE_KEY` | Clave de servidor: exclusivamente para confirmar las cargas verificadas |
| `R2_ACCOUNT_ID` | Cuenta Cloudflare |
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | Credenciales S3 de lectura/escritura limitadas al bucket |
| `R2_BUCKET` | Nombre del bucket privado, por ejemplo `retinazo-retinas` |
| `MAX_IMAGE_BYTES` | Límite por foto; predeterminado 10 MiB, máximo admitido 20 MiB |
| `SIGNED_URL_SECONDS` | Vida de los enlaces de descarga; 60 segundos, configurable entre 15 y 300 |

El proceso rechaza configuraciones incompletas y omite sus valores en el error de arranque. No existe un modo que cambie automáticamente a un almacenamiento ficticio.

## Comprobar localmente

Las pruebas son locales; el alojamiento final será remoto.

```sh
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.lock
.venv/bin/pip install --no-deps -e .
.venv/bin/python -m pytest -q
```

Con variables válidas, para desarrollo:

```sh
.venv/bin/uvicorn retinazo_api.main:app --host 127.0.0.1 --port 8000 --no-access-log
```

No se utiliza esa dirección local en un APK de uso remoto. Flutter exige un origen HTTPS para `IMAGE_API_URL`.

## Desplegar en Render

El archivo `render.yaml` de la raíz permite crear el servicio mediante un
Blueprint. Selecciona la rama que contenga esta preparación. Define explícitamente
la instancia Free para la primera prueba y solicita las credenciales en Render
(`sync: false`); no contiene secretos. Los despliegues automáticos están
desactivados para revisar cada publicación. Crear el archivo no crea un servicio
ni aplica la migración SQL. La instancia actual se creó mediante la API de Render;
la migración y la comprobación remota ya se completaron.

1. Tener el código revisado en un repositorio al que Render pueda acceder.
2. Crear un **Web Service** con runtime Docker y directorio raíz `backend`. Su Dockerfile instala las versiones de `requirements.lock`.
3. Elegir la instancia. Free se suspende tras 15 minutos sin tráfico y puede tardar aproximadamente un minuto en reactivarse. Para permanecer activo sin suspensión por inactividad se necesita una instancia de pago. El plan y costo se eligen antes de contratar.
4. Añadir los secretos anteriores en Render. Mantener el bucket privado, con dominio público y `r2.dev` desactivados.
5. Aplicar previamente `supabase/migrations/20261105130000_r2_image_storage.sql` en Supabase, después de las migraciones anteriores. Ya está aplicada al proyecto Retinazo alojado; no repetirla allí.
6. Configurar `/health` como ruta de comprobación. El comando del contenedor escucha en `0.0.0.0:$PORT`, que Render asigna, con un worker. Render publica la URL HTTPS.
7. Comprobar las rutas autenticadas con imágenes sintéticas y permisos de profesional/administrador. La prueba local no certifica las credenciales ni las políticas reales de R2.
8. Añadir el origen HTTPS publicado a `IMAGE_API_URL` en la configuración pública local de Flutter y recompilar el APK.

El servicio no necesita disco persistente: los archivos temporales se cierran tras cada petición, los originales quedan en R2 y los registros en PostgreSQL. Hay que medir la memoria con las imágenes reales para elegir la instancia. La futura inferencia puede requerir otro tamaño de instancia o un servicio con GPU; no se asume que la instancia de imágenes pueda ejecutar el modelo.

Para repetir voluntariamente la comprobación remota desde la raíz del repositorio:

```sh
backend/.venv/bin/python scripts/smoke_remote_images.py --run
```

Necesita el archivo protegido `backend/.env`, incluido `SUPABASE_ACCESS_TOKEN` para
limpiar exclusivamente los registros temporales de la prueba. Este token y
`RENDER_API_KEY` son credenciales de administración locales y no se incluyen en
las variables del servicio desplegado ni en Flutter.

Render Free también tiene límites de tráfico, incluidas transferencias hacia almacenamiento externo. R2 sin cobro de egreso no implica que todo el alojamiento de la API sea gratuito.

## Contrato HTTP

Actualización 1.3.0: solo el profesional responsable puede cargar imágenes de un
paciente activo. La API verifica su rol y actividad antes de escribir en R2; la
RPC vuelve a comprobarlo antes de confirmar la carga. El administrador conserva
la consulta global, pero no carga imágenes ni crea nuevas evaluaciones. Los
pacientes desactivados conservan la lectura autorizada de sus imágenes e historial.

Todas las rutas de evaluación requieren `Authorization: Bearer <sesión Supabase>`. No reciben contraseñas, claves de R2, claves de servidor ni roles elegidos por el cliente.

- `GET /health`: identifica el servicio; `model=not_integrated`.
- `PUT /v1/evaluations/{uuid}/images`: multipart con exactamente tres campos `files`, en orden de posición 1, 2 y 3. El borrador y sus metadatos deben existir. Respuesta `204` tras guardar y confirmar el conjunto completo.
- `GET /v1/evaluations/{uuid}/images`: devuelve posiciones y enlaces privados temporales. La app comprueba tamaño y hash antes de presentar las fotos.

FastAPI consulta Auth en Supabase, verifica correo/activación y consulta la evaluación usando el JWT del usuario para aplicar RLS. También se comprueba la autorización en la RPC de finalización, por si cambian los permisos durante una carga.

Se valida el conjunto completo antes de escribir en R2: exactamente tres archivos, tamaño, hash, codificación real JPEG/PNG, decodificación válida y hasta 40 millones de píxeles. No se recomprime ni se cambia la resolución de los originales. Esta es validación técnica del archivo; no evalúa calidad del fondo de ojo ni confirma el ojo/paciente fotografiado.

Las claves son `evaluations/{uuid}/{posición}-{sha256}.{extensión}`. Al reintentar, los mismos bytes utilizan la misma clave. Solo el backend escribe objetos; el móvil recibe únicamente enlaces GET. Esto evita que un enlace de carga aún vigente sobrescriba una imagen después de su verificación.

La RPC de servidor confirma las tres referencias de forma atómica y pasa a `pending_analysis`, sin insertar una predicción. R2 y PostgreSQL no comparten transacción: si una carga parcial falla, pueden quedar objetos privados sin confirmar. El reintento reutiliza sus claves. Antes de producción se debe definir la limpieza periódica de objetos huérfanos con margen de seguridad; no se borran automáticamente objetos cuya confirmación pudo haberse completado aunque se perdiera la respuesta HTTP.

Los enlaces GET son credenciales temporales: quien posea uno puede usarlo hasta que venza. La desactivación de una cuenta impide emitir enlaces nuevos, pero no revoca instantáneamente los ya emitidos. No se guardan esos enlaces en PostgreSQL ni se imprimen en logs. El comando de despliegue desactiva el access log de Uvicorn.

## Referencias

- [R2 y boto3](https://developers.cloudflare.com/r2/examples/aws/boto3/).
- [Enlaces firmados](https://developers.cloudflare.com/r2/api/s3/presigned-urls/).
- [Render y FastAPI](https://render.com/docs/deploy-fastapi).
- [Límites del alojamiento gratuito](https://render.com/docs/free).
