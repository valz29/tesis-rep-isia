# Organización y revisión del código

Revisión local del 12 de noviembre de 2026, en `tesis-rep-isia`.

## Alcance del inventario

Se inventariaron los 265 archivos versionados existentes al iniciar la revisión, sus tamaños, archivos fuente duplicados y archivos locales fuera de dependencias y cachés. Se revisaron las responsabilidades de Flutter, FastAPI, SQL, scripts de pruebas y modelo experimental. El código generado de las plataformas se conserva.

Los únicos cinco archivos versionados vacíos eran los `__init__.py` de `backend/retinazo_api` y sus cuatro subpaquetes. Son marcadores de paquetes Python, no implementaciones abandonadas. Se conservaron y se añadió una descripción de su responsabilidad. No se encontraron archivos fuente idénticos duplicados.

Las interfaces de repositorios Dart y los protocolos Python declaran contratos: carecer de un cuerpo de implementación es correcto. Los repositorios en memoria y el acceso de prueba se conservan porque los utilizan las pruebas; el arranque real selecciona explícitamente Supabase.

`build`, `.dart_tool`, `.gradle`, `.kotlin`, entornos virtuales, registrantes generados, cachés y archivos de configuración privados no son código de negocio. No se borraron APK, dependencias, credenciales ni recursos necesarios para compilar. La limpieza no cambia datos alojados ni despliega servicios.

## Distribución del repositorio

| Carpeta | Responsabilidad |
|---|---|
| `app/` | Flutter, recursos, configuración de plataformas y pruebas móviles |
| `backend/` | API FastAPI para autorizar y almacenar imágenes privadas |
| `supabase/` | Migraciones históricas, restricciones y políticas SQL |
| `model/` | Línea base experimental de entrenamiento, separada de la API |
| `scripts/` | Verificación de PostgreSQL y comprobaciones remotas explícitas |
| `docs/` | Relaciones, permisos, almacenamiento y organización |

## Cambios de organización aplicados

- `features/*/data/models`: mappers para pacientes, evaluaciones y administración. Traducen columnas y payloads sin acoplar las entidades al proveedor.
- `features/evaluations/data/datasources/image_api_client.dart`: transporte HTTP hacia FastAPI. Los repositorios conservan la coordinación de persistencia y caché.
- `features/admin/presentation/pages/admin_user_edit_screen.dart`: edición separada del listado y búsqueda de usuarios.
- `features/home/presentation/widgets/home_drawer.dart`: menú lateral con datos y callbacks explícitos, separado de la composición del inicio. Se retiró el texto de versión fijo que había quedado desactualizado.
- `backend/retinazo_api/presentation/middleware.py`: límite de carga HTTP separado de `main.py`, que compone la aplicación.
- Imports Dart ordenados y comprobados por `directives_ordering`; configuración sin comentarios de plantilla redundantes.
- Documentación de arquitectura consolidada para describir el estado vigente.

La conversión de pacientes ahora admite `owner_id = null` para los expedientes archivados permitidos por el esquema. Es la corrección de compatibilidad de datos incluida en esta reorganización; no modifica las reglas de asignación.

## Criterios para continuar

1. Añadir cada funcionalidad a su módulo, conservando `domain`, `data` y `presentation`.
2. Mantener HTTP, SDK y nombres de columnas dentro de `data`; los mappers no realizan consultas.
3. Crear un caso de uso cuando una operación reúne reglas o una secuencia de negocio; evitar clases vacías que solo completen una plantilla.
4. Separar pantallas y componentes cuando tengan responsabilidades propias, sin introducir abstracciones para cada bloque visual.
5. Conservar migraciones aplicadas; los cambios de esquema futuros se añaden como migraciones nuevas.
6. Comprobar arquitectura, análisis, formato y comportamiento antes de integrar cambios.

## Verificación

En `app/`:

```sh
flutter analyze --no-pub
flutter test --no-pub
dart format --output=none --set-exit-if-changed lib test
```

En la raíz:

```sh
backend/.venv/bin/python -m pytest backend/tests -q
python3 scripts/test_database.py
git diff --check
```

Las pruebas PostgreSQL se ejecutan en un contenedor desechable sin modificar la base alojada. El script `smoke_remote_images.py` sí utiliza servicios remotos y no forma parte de una limpieza local de código.

## Trabajo funcional pendiente

La recuperación persistente de cargas, edición concurrente, paginación, actualización de datos remotos, SMTP, OAuth de Google, firma de distribución y modelo de análisis requieren tareas funcionales separadas. Esta reorganización no afirma haber completado esas integraciones ni la validación en un teléfono físico.
