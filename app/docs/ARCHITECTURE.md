# Arquitectura de Retinazo

Estado del código revisado el 17 de noviembre de 2026. Esta descripción corresponde a la estructura vigente; no confirma un nuevo despliegue ni validación en teléfono físico.

## Organización por funcionalidad y capas

```text
lib/
├── main.dart
├── app/                         Arranque, configuración, dependencias, sesión y rutas
├── core/                        Errores comunes, traducción de fallos y tema
├── shared/                      Logo y contenedor de páginas
└── features/
    ├── auth/                    Identidad y acceso
    ├── admin/                   Gestión administrativa
    ├── patients/                Expedientes de pacientes
    ├── evaluations/             Tres imágenes, historial y resultados
    └── home/                    Inicio y menú lateral (solo presentación)

test/
├── app/                         Configuración
├── architecture/                Reglas de dependencias
├── features/                    Pruebas por funcionalidad
└── support/
    ├── fakes/                   Cuatro repositorios de prueba
    ├── fixtures.dart            Composición y datos sintéticos de prueba
    └── auth_storage.dart        Adaptador de almacenamiento de pruebas
```

Cada módulo con lógica de negocio conserva tres capas, sin subcarpetas por tipo de archivo:

```text
patients/
├── data/
│   ├── patient_mapper.dart              Conversión de filas y parámetros
│   └── supabase_patient_repository.dart Persistencia remota
├── domain/
│   ├── patient.dart                     Entidad
│   ├── patient_repository.dart          Contrato
│   ├── register_patient.dart            Caso de uso
│   ├── update_patient.dart              Caso de uso
│   └── validate_patient.dart            Reglas compartidas
└── presentation/
    ├── patients_controller.dart         Estado y acciones
    ├── patient_form_screen.dart         Registro y edición
    ├── patient_detail_screen.dart       Detalle
    └── patient_selection_screen.dart    Lista y selección
```

La simplificación reduce los directorios de `lib` de 62 a 22. Conserva los 87 archivos Dart originales: 83 en `lib` y cuatro repositorios de prueba en `test/support/fakes`. Los nombres de archivo identifican entidades, repositorios, casos de uso, controladores y pantallas sin agregar niveles al explorador. El [mapa de rutas](../../docs/FLUTTER_FILE_MAP.csv) permite encontrar cada archivo anterior.

Solo se crean carpetas con una responsabilidad implementada. La separación de capas depende de sus imports y contratos, no del número de carpetas.

## Dependencias

- `domain` usa Dart y errores comunes; no importa Flutter, Supabase, HTTP ni las capas `data`, `presentation` o `app`.
- `data` implementa los contratos del dominio y traduce las respuestas externas. Los mappers contienen los nombres de columnas y payloads; los repositorios coordinan consultas y persistencia.
- `presentation` usa entidades, contratos y casos de uso. No consulta Supabase ni HTTP directamente.
- `RetinazoApp` exige dependencias explícitas. Su creador es responsable de liberarlas: `AppBootstrap` en producción y las pruebas en sus propios recorridos. No contiene un modo de prueba implícito.
- `app/dependencies.dart` es el punto de composición que conecta repositorios y controladores. La inyección es manual; no requiere un contenedor externo.
- `SessionController` coordina identidad, permisos de interfaz y carga de módulos. Las comprobaciones definitivas de autorización permanecen en PostgreSQL y FastAPI.

Algunas consultas y operaciones administrativas simples se delegan del controlador al contrato del repositorio. No todos los métodos tienen una clase de caso de uso independiente. Los casos de uso se utilizan donde hay reglas o una secuencia de negocio que centralizar.

## Arranque y sesión

```text
main → AppBootstrap → AppDependencies.remote → RetinazoApp → AuthGate
```

`AppConfig` lee configuración pública de compilación. `AppBootstrap` valida esa configuración e inicializa Supabase. `AuthLinkCoordinator` procesa enlaces de confirmación y recuperación mediante PKCE. `AuthGate` muestra acceso, recuperación o navegación autenticada según la sesión.

El arranque real usa repositorios remotos. Las implementaciones `in_memory` y `preview` viven exclusivamente en `test/support/fakes` y se inyectan desde las pruebas; no sustituyen automáticamente una conexión fallida. Cerrar sesión descarta cachés locales y credenciales del dispositivo, sin borrar datos remotos.

## Datos estructurados e imágenes

Las cuentas se autentican con Supabase Auth. Los perfiles protegidos determinan el rol y la activación. Los pacientes, evaluaciones, resultados y metadatos usan PostgreSQL con RLS.

```text
Formulario → Controlador → Caso de uso / contrato → Repositorio → Supabase
```

`PatientMapper`, `EvaluationMapper` y `AdminMapper` aíslan la conversión de filas y parámetros dentro de `data`. El responsable de un paciente archivado puede ser nulo; el mapper respeta el tipo opcional de la entidad y la restricción SQL.

Cada evaluación reúne exactamente tres imágenes distintas de un paciente y un solo ojo. La confirmación manual no verifica automáticamente que las fotos pertenezcan al mismo ojo.

```text
SupabaseEvaluationRepository
  → save_evaluation_draft (metadatos en PostgreSQL)
  → ImageApiClient (FastAPI)
  → originales privados en Cloudflare R2
```

`ImageApiClient` vive en `evaluations/data`. FastAPI verifica identidad, permisos, contenido y hashes antes de confirmar la carga mediante una RPC privilegiada. Las lecturas usan enlaces HTTPS temporales sin reenviarles el token de Supabase.

El servicio FastAPI está preparado para ejecutarse en Render. El dominio móvil no conoce R2, Render ni sus claves. El modelo de predicción todavía no está integrado: no se fabrican grados ni confianza.

## Roles y ciclo de vida

- Un profesional activo con correo confirmado administra sus pacientes y realiza sus evaluaciones.
- El administrador gestiona usuarios y expedientes globales. Registra pacientes eligiendo un profesional responsable; no recibe pacientes ni crea nuevas evaluaciones clínicas.
- Reasignar un paciente conserva la autoría histórica de sus evaluaciones.
- Desactivar un expediente registra motivo y conserva historial e imágenes; bloquea nuevas evaluaciones y cargas.
- Reactivar requiere un responsable profesional elegible.
- Los resultados y la confirmación de almacenamiento no se escriben libremente desde Flutter.

Las cinco migraciones en `supabase/migrations` describen la evolución del esquema. No se reescriben migraciones ya aplicadas para realizar una limpieza de código.

## Presentación

Los controladores usan `ChangeNotifier`. Las pantallas observan cambios con `ListenableBuilder`.

- `HomeScreen` compone el inicio; `HomeDrawer` dibuja el menú con datos y callbacks explícitos.
- `AdminUsersScreen` lista y busca; `AdminUserEditScreen` edita una cuenta.
- `CaptureController` pertenece a una pantalla de captura y se libera al salir.
- `shared` contiene el logo y el contenedor de páginas reutilizables.
- `AppTheme` mantiene colores, tipografía y estilos comunes.

## Convenciones y verificación

- Archivos y carpetas en `snake_case`; clases en `UpperCamelCase`.
- Se conservan los nombres públicos actuales, incluidos los términos clínicos en español, para evitar renombrados masivos sin beneficio funcional.
- Imports ordenados por SDK de Dart, paquetes y rutas relativas; el analizador exige `directives_ordering`.
- `dart format` define el formato. Los errores de infraestructura se traducen a `AppFailure` sin exponer respuestas sensibles.
- Las pruebas de arquitectura comprueban la independencia del dominio y bloquean acceso directo a infraestructura desde presentación.
- Los adaptadores remotos y la conversión de datos se comprueban con respuestas sintéticas.

Desde `app/`:

```sh
flutter analyze --no-pub
flutter test --no-pub
dart format --output=none --set-exit-if-changed lib test
```

Desde la raíz, las comprobaciones adicionales son `backend/.venv/bin/python -m pytest backend/tests -q` y `python3 scripts/test_database.py`. Esta última usa PostgreSQL desechable en Docker, sin cambiar Supabase alojado.

## Pendientes funcionales separados de esta reorganización

- Recuperación persistente de fotografías tras una carga interrumpida y cierre de la app.
- Control de ediciones simultáneas, paginación de pacientes e historial y estadísticas globales independientes de los listados descargados.
- Actualización de cambios remotos de propiedad o estado sin recarga manual.
- Validación completa en teléfono físico, SMTP externo, activación de Google OAuth y firma de distribución Android.
- Integración del modelo de análisis.

Ver [administración](../../docs/ADMINISTRATION.md), [base de datos](../../docs/DATABASE.md), [imágenes R2](../../docs/R2_STORAGE.md) e [inventario y criterios de organización](../../docs/CODE_ORGANIZATION.md).

## Guardado y miniaturas · 1.3.1

`EvaluationRepository.save` devuelve el registro persistido. El controlador lo incorpora al historial local sin solicitar la lista completa. La pantalla muestra espera, evita navegación y envíos duplicados durante la carga y regresa al inicio tras el éxito. Los errores permiten reintentar el mismo identificador.

`EvaluationThumbnail` solicita una miniatura al repositorio para cada fila visible. Se descarga solo el primer original autorizado, se verifica su tamaño/hash y `thumbnail_encoder.dart` genera una vista pequeña en memoria. La cola limita la concurrencia y la caché mantiene hasta 40 miniaturas; ambas se descartan al cerrar sesión. Las tres imágenes de detalle se descargan concurrentemente para reducir la espera y evitar consumir sus enlaces temporales en cola.

La apertura de captura inicia una preparación HTTP opcional contra `/health`; fallar en esa preparación no bloquea elegir fotos. No es un monitor periódico ni garantiza que el alojamiento responda sin demora.


## Carga optimizada y botón Atrás · 1.3.3

El historial solicita una miniatura privada de 192 × 192 píxeles como máximo al endpoint `/v1/evaluations/{id}/thumbnail`. FastAPI comprueba la sesión y los permisos en cada petición; crea el derivado en R2 durante la primera consulta y lo reutiliza después. Los originales permanecen intactos. No requiere una migración SQL. Si el backend aún no ofrece el endpoint (HTTP 404), la app conserva el recorrido anterior como compatibilidad.

Flutter admite dos solicitudes de miniaturas simultáneas, comparte solicitudes repetidas del mismo registro y conserva hasta 40 vistas pequeñas en memoria. La sesión limpia estas cachés. El detalle publica cada foto cuando termina su descarga y verificación, respetando su posición aunque lleguen fuera de orden. Las visitas recientes reutilizan los originales de hasta tres evaluaciones, tras volver a comprobar acceso al registro. La UI mantiene las imágenes parciales fuera de la entidad clínica: una evaluación sigue requiriendo tres imágenes.

`AuthGate` conecta el navegador de sesión con `NavigatorPopHandler`. El botón Atrás del sistema regresa a la ruta anterior; desde el inicio, primero cierra el menú si está abierto. El bloqueo de navegación mientras se guarda una evaluación se conserva. La salida de la app corresponde a la raíz de navegación. La apariencia y los gestos del teléfono aún requieren una prueba física.

La primera miniatura de un registro antiguo y la reactivación de Render Free aún pueden tardar. Estas mejoras reducen transferencia y esperas entre imágenes, pero no garantizan un tiempo fijo en todas las redes.
