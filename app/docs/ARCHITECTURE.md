# Arquitectura de Retinazo

Estado del código revisado el 12 de noviembre de 2026. Esta descripción corresponde a la estructura vigente; no confirma un nuevo despliegue ni validación en teléfono físico.

## Organización por funcionalidad y capas

```text
lib/
├── main.dart
├── app/                         Arranque, dependencias, sesión y navegación
│   ├── config/
│   └── router/
├── core/                        Errores, traducción de fallos y tema
├── shared/widgets/              Componentes comunes
└── features/
    ├── auth/                    Identidad y acceso
    ├── admin/                   Gestión administrativa
    ├── patients/                Expedientes de pacientes
    ├── evaluations/             Tres imágenes, historial y resultados
    └── home/                    Inicio y menú lateral
```

Los módulos con lógica de negocio usan estas capas; `home` solo necesita presentación:

```text
feature/
├── domain/
│   ├── entities/                Datos e invariantes de negocio
│   ├── repositories/            Contratos de acceso
│   └── usecases/                Operaciones y validaciones
├── data/
│   ├── models/                  Mappers de filas y parámetros de persistencia
│   ├── datasources/             Clientes de transporte cuando corresponde
│   └── repositories/            Implementaciones de contratos
└── presentation/
    ├── controllers/             Estado y acciones de interfaz
    ├── pages/                   Pantallas
    └── widgets/                 Componentes del módulo
```

Solo se crean carpetas que tienen una responsabilidad implementada. No se añaden archivos vacíos para completar una plantilla.

## Dependencias

- `domain` usa Dart y errores comunes; no importa Flutter, Supabase, HTTP ni las capas `data`, `presentation` o `app`.
- `data` implementa los contratos del dominio y traduce las respuestas externas. Los mappers contienen los nombres de columnas y payloads; los repositorios coordinan consultas y persistencia.
- `presentation` usa entidades, contratos y casos de uso. No consulta Supabase ni HTTP directamente.
- `app/dependencies.dart` es el punto de composición que conecta repositorios y controladores. La inyección es manual; no requiere un contenedor externo.
- `SessionController` coordina identidad, permisos de interfaz y carga de módulos. Las comprobaciones definitivas de autorización permanecen en PostgreSQL y FastAPI.

Algunas consultas y operaciones administrativas simples se delegan del controlador al contrato del repositorio. No todos los métodos tienen una clase de caso de uso independiente. Los casos de uso se utilizan donde hay reglas o una secuencia de negocio que centralizar.

## Arranque y sesión

```text
main → AppBootstrap → AppDependencies.remote → RetinazoApp → AuthGate
```

`AppConfig` lee configuración pública de compilación. `AppBootstrap` valida esa configuración e inicializa Supabase. `AuthLinkCoordinator` procesa enlaces de confirmación y recuperación mediante PKCE. `AuthGate` muestra acceso, recuperación o navegación autenticada según la sesión.

El arranque real usa repositorios remotos. Las implementaciones `in_memory` y `preview` son dobles para pruebas con inyección explícita; no sustituyen automáticamente una conexión fallida. Cerrar sesión descarta cachés locales y credenciales del dispositivo, sin borrar datos remotos.

## Datos estructurados e imágenes

Las cuentas se autentican con Supabase Auth. Los perfiles protegidos determinan el rol y la activación. Los pacientes, evaluaciones, resultados y metadatos usan PostgreSQL con RLS.

```text
Formulario → Controlador → Caso de uso / contrato → Repositorio → Supabase
```

`PatientMapper`, `EvaluationMapper` y `AdminMapper` aíslan la conversión de filas y parámetros dentro de `data/models`. El responsable de un paciente archivado puede ser nulo; el mapper respeta el tipo opcional de la entidad y la restricción SQL.

Cada evaluación reúne exactamente tres imágenes distintas de un paciente y un solo ojo. La confirmación manual no verifica automáticamente que las fotos pertenezcan al mismo ojo.

```text
SupabaseEvaluationRepository
  → save_evaluation_draft (metadatos en PostgreSQL)
  → ImageApiClient (FastAPI)
  → originales privados en Cloudflare R2
```

`ImageApiClient` vive en `evaluations/data/datasources`. FastAPI verifica identidad, permisos, contenido y hashes antes de confirmar la carga mediante una RPC privilegiada. Las lecturas usan enlaces HTTPS temporales sin reenviarles el token de Supabase.

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
- `shared/widgets` contiene el logo y el contenedor de páginas reutilizables.
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
