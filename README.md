# Retinazo

Aplicación móvil de apoyo al tamizaje de retinopatía diabética mediante aprendizaje profundo. Proyecto de tesis de pregrado, Universidad Privada Antenor Orrego (UPAO), Ingeniería de Computación y Sistemas.

Autores: Gabriel Leyva Valqui y Alejandro Rodriguez Gonzales.

La salida del sistema es apoyo al tamizaje, no un diagnóstico.

## Estructura

| Directorio | Contenido |
|---|---|
| [`app/`](app/) | Aplicación móvil |
| [`backend/`](backend/) | FastAPI desplegado en Render para imágenes privadas en R2 |
| [`model/`](model/) | Entrenamiento y evaluación del modelo |
| [`supabase/`](supabase/) | Migraciones SQL y reglas de acceso aplicadas en Supabase |
| [`docs/DATABASE.md`](docs/DATABASE.md) | Tablas, relaciones, permisos y normalización |
| [`docs/ADMINISTRATION.md`](docs/ADMINISTRATION.md) | Roles, panel administrativo y registro con confirmación |
| [`scripts/`](scripts/) | Pruebas de base de datos y comprobación remota con imágenes sintéticas |

La integración de Cloudflare R2 y Render se explica en [docs/R2_STORAGE.md](docs/R2_STORAGE.md). La cuarta migración está aplicada al proyecto alojado. La API está disponible en [retinazo-images.onrender.com/health](https://retinazo-images.onrender.com/health); el análisis mediante modelo sigue pendiente.
