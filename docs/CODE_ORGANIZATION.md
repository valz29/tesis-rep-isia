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

- `features/*/data`: mappers para pacientes, evaluaciones y administración. Traducen columnas y payloads sin acoplar las entidades al proveedor.
- `features/evaluations/data/image_api_client.dart`: transporte HTTP hacia FastAPI. Los repositorios conservan la coordinación de persistencia y caché.
- `features/admin/presentation/admin_user_edit_screen.dart`: edición separada del listado y búsqueda de usuarios.
- `features/home/presentation/home_drawer.dart`: menú lateral con datos y callbacks explícitos, separado de la composición del inicio. Se retiró el texto de versión fijo que había quedado desactualizado.
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

La recuperación persistente de cargas, edición concurrente, paginación, actualización de datos remotos, SMTP, OAuth de Google y modelo de análisis requieren tareas funcionales separadas. La firma permanente de Android se configura desde la versión 1.3.6; ver [distribución](ANDROID_RELEASES.md). Esta reorganización no afirma haber completado las integraciones pendientes ni la validación en un teléfono físico.

## Segunda comprobación de archivos y flujo · 12 de noviembre

Se comprobó la alcanzabilidad de los archivos Dart desde `main.dart` y las pruebas: no se detectaron bibliotecas huérfanas. Los cinco `__init__.py` son marcadores documentados de paquetes usados por el backend y su empaquetado. No se eliminan por carecer de funciones ejecutables. No se detectaron archivos versionados vacíos que justificaran borrado.

La versión móvil 1.3.1 corrige el regreso tras guardar y las miniaturas del historial. Estas correcciones no cambian las migraciones, el modelo ni las credenciales alojadas.


## Simplificación de carpetas · 17 de noviembre de 2026

Se conservan los módulos y las capas `data`, `domain` y `presentation`, con sus archivos directamente dentro de cada capa. Se retiran los niveles `entities`, `repositories`, `usecases`, `models`, `datasources`, `pages`, `controllers`, `widgets`, `validators` y `formatters` bajo esas capas. `app`, `core` y `shared` también contienen sus archivos directamente. `lib` pasa de 62 a 22 directorios.

Los cuatro repositorios de prueba se trasladan a `app/test/support/fakes`. La composición móvil exige todos los contratos, incluido el administrativo, y `RetinazoApp` requiere dependencias explícitas. `AppBootstrap` conserva la creación y liberación de las dependencias remotas. Las pruebas construyen sus propios dobles; el APK no importa código de `test`.

Se actualizaron los imports, las pruebas y la documentación. El [mapa anterior y actual](FLUTTER_FILE_MAP.csv) incluye los 87 archivos originales. Las reglas de arquitectura comprueban también que `lib` no importe `test`.

El backend conserva su estructura existente, adecuada a su tamaño. La reorganización mantiene las interfaces de API, el esquema SQL, los permisos y las funcionalidades. Los problemas funcionales identificados en el análisis, como la recuperación de cargas y la paginación, requieren su propia implementación y no se declaran resueltos aquí.

El icono de instalación de Android e iOS reutiliza `app/assets/branding/retinazo-eye.png`. `app/flutter_launcher_icons.yaml` permite reproducir sus tamaños y las capas adaptativas de Android. El fondo adaptativo usa el color de la app. La compilación iOS requiere macOS y no se valida en este equipo Linux.

Verificación local de esta reorganización: `flutter analyze --no-pub` sin incidencias, 47 pruebas Flutter aprobadas, formato de 104 archivos Dart sin cambios pendientes y APK Android 1.3.2+6 compilado en modo release. Se verificaron el catálogo iOS y los recursos del icono incluidos en el APK; no se ejecutó una compilación iOS ni una prueba física. No se modificaron servicios alojados.


## Optimización validada · 18 de noviembre de 2026

Retinazo 1.3.3+7 conecta Atrás del sistema al navegador de sesión y cierra el menú lateral antes de abandonar el inicio. El historial comparte solicitudes de miniatura, permite dos cargas simultáneas y conserva una caché de sesión acotada. El detalle muestra imágenes verificadas conforme llegan, sin introducir evaluaciones clínicas incompletas en el dominio.

Validación: análisis Flutter sin incidencias, 53 pruebas Flutter y 20 pruebas backend aprobadas. El backend de miniaturas se publicó en Render desde el commit `22518e4`. Una prueba remota con cuentas e imágenes sintéticas comprobó creación y reutilización del derivado, acceso por propietario y administrador, denegación a anónimos/otros profesionales/cuentas desactivadas e integridad de originales. La limpieza eliminó únicamente los registros, cuentas y objetos creados por esa prueba. La experiencia con fotos reales y los gestos físicos del teléfono requieren comprobación en el dispositivo.


### Presentación de acceso · 1.3.4

`auth_visuals.dart` mantiene los componentes visuales y animaciones compartidos de bienvenida y acceso dentro de la presentación de `auth`. Las pantallas usan los mismos controladores, rutas y contratos de autenticación. Las animaciones finitas no añaden dependencias ni lógica de red a la UI. Las pruebas de diseño cubren entrada, movimiento reducido, teclado y texto al 200 % en pantalla pequeña y horizontal.
