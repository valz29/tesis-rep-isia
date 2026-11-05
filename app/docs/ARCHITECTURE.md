# Arquitectura de Retinazo

Estado: aplicación Flutter con Supabase y almacenamiento R2 mediante FastAPI en Render, 5 de noviembre de 2026.

Esta arquitectura conserva el recorrido y la identidad visual del aplicativo. La implementación actual usa adaptadores Supabase para autenticación, pacientes y evaluaciones, y `ImageApiClient` para las imágenes mediante FastAPI en Render y R2. El esquema alojado y el administrador inicial están activados. El modelo aún no está integrado. Las secciones sobre la reorganización original describen su etapa inicial; la actualización al final detalla el cableado remoto actual.

El documento `CONTEXTO_TESIS.md` proporcionado por el usuario se utiliza como contexto del sistema. Sus tecnologías propuestas y sus decisiones pendientes no se consideran implementadas por esta reorganización.

## Organización del código

Se usa Clean Architecture organizada por funcionalidad. Cada módulo concentra sus propias capas, en lugar de reunir todas las pantallas o todos los servicios en una sola carpeta.

```text
lib/
├── main.dart                      # Punto de entrada
├── app/
│   ├── app.dart                   # MaterialApp y ciclo de vida
│   ├── dependencies.dart          # Construcción e inyección de dependencias
│   ├── app_scope.dart             # Acceso a la sesión por encima del Navigator
│   ├── session_controller.dart    # Coordinación de sesión y cierre
│   └── router/app_routes.dart     # Navegación centralizada
├── core/
│   ├── errors/app_failure.dart     # Errores esperados, sin dependencia de Flutter
│   └── theme/app_theme.dart        # Tema visual común
├── shared/widgets/                # Componentes visuales comunes sin reglas clínicas
│   ├── page_body.dart
│   └── retinazo_logo.dart
└── features/
    ├── auth/
    │   ├── domain/                # Personal, contrato de acceso, ingreso y salida
    │   ├── data/                  # Implementación de acceso de prueba
    │   └── presentation/          # Controlador, validadores y pantallas
    ├── patients/
    │   ├── domain/                # Paciente, contrato de repositorio, registro
    │   ├── data/                  # Repositorio en memoria
    │   └── presentation/          # Controlador, formulario, listado y búsqueda
    ├── evaluations/
    │   ├── domain/                # Evaluación, borrador, imagen, resultado y casos de uso
    │   ├── data/                  # Repositorio en memoria y adaptador de cámara/galería
    │   └── presentation/          # Controladores, pantallas, widgets y formatos de texto
    └── home/presentation/         # Inicio y menú lateral
```

`home` solo necesita presentación por ahora. No se crearon capas vacías, clientes HTTP, DTO ni fuentes de datos adicionales para funcionalidades que aún no existen.

## Responsabilidad de cada capa

| Capa | Contiene | Evita |
|---|---|---|
| `domain` | Entidades, reglas, contratos de repositorios y casos de uso | Widgets, plugins, JSON, HTTP, SQL y archivos del dispositivo |
| `data` | Implementaciones de contratos y acceso al dispositivo | Navegación y estado visual |
| `presentation` | Pantallas, controladores de estado, validación visual y formatos de texto | Instanciar almacenamiento o acceder directamente a cámara/servidor |
| `app` | Ensamblado, navegación y coordinación entre módulos | Concentrar las reglas de pacientes o evaluaciones |
| `core` / `shared` | Utilidades y componentes comunes | Convertirse en un almacén global de lógica de funcionalidades |

Las dependencias del dominio apuntan a Dart y a contratos del propio dominio. Las implementaciones de datos dependen de esos contratos. Las pantallas llaman a los controladores; los controladores utilizan casos de uso y contratos de repositorios.

```text
Pantalla → Controlador → Caso de uso → Contrato de repositorio
                                            ↑
                              Implementación en data

app/dependencies.dart conecta contratos e implementaciones.
```

Los módulos de evaluaciones consultan el contrato de pacientes para comprobar que el paciente existe. No acceden al repositorio concreto de pacientes. Las páginas utilizan `AppRoutes` como frontera de navegación; el router construye las páginas y les entrega las dependencias.

## Estado e inyección

Se mantiene `ChangeNotifier` para los controladores de presentación, sin añadir otra librería de estado:

- `AuthController`: ingreso, personal actual, carga y errores de acceso.
- `PatientsController`: listado temporal, búsqueda, registro y errores.
- `EvaluationsController`: preparación, guardado, historial y conteos de evaluaciones.
- `CaptureController`: tres posiciones de imagen, selección, confirmación, reemplazo y eliminación. Pertenece a una pantalla de captura y se libera al salir.

`SessionController` agrupa los controladores de funcionalidades y coordina el cierre de sesión. No reemplaza a los repositorios. `AppScope` expone esta composición a la navegación, sin guardar registros por sí mismo.

`AppDependencies.inMemory()` selecciona las implementaciones actuales. El constructor de `AppDependencies` admite otros repositorios y permite inyectar reloj y generador de identificadores para pruebas. `RetinazoApp` libera las dependencias que crea; cuando se inyectan desde fuera, quien las proporciona es responsable de liberarlas.

## Modelo de información

| Entidad | Datos y responsabilidad |
|---|---|
| `Patient` | ID, DNI, nombres, apellidos, nacimiento, sexo y datos opcionales. No contiene el ojo ni las observaciones de una visita. |
| `EvaluationDraft` | Paciente, ojo y observaciones mientras se prepara una evaluación. |
| `EvaluationImage` | Contenido de una imagen seleccionada; protege sus bytes de modificaciones externas. |
| `Evaluation` | ID propio, ID del paciente, ojo, observaciones, tres imágenes, fecha, ID del profesional, estado y resultado opcional. |
| `DetectionResult` | Grado ICDR 0–4, confianza opcional de 0 a 1 y versión del modelo. Su existencia en el dominio no significa que ya haya inferencia. |
| `StaffMember` | Identidad del personal usado por la sesión; el acceso actual no verifica cuentas reales. |

Un paciente puede tener evaluaciones de ambos ojos y de distintas visitas sin duplicar su identidad. No se diseñó todavía un modelo de citas/visitas compartidas entre ambos ojos.

Los estados del dominio distinguen `pendingAnalysis`, `notGradable` y `completed`. Una evaluación completada requiere resultado; una pendiente o no graduable no lleva grado. El flujo actual solo crea evaluaciones pendientes. La pantalla de resultado está preparada visualmente para ese estado actual; mostrar respuestas reales y motivos de no graduabilidad será trabajo de integración.

## Reglas actuales

- El registro valida DNI de ocho dígitos, nombres, nacimiento no futuro y teléfono opcional de nueve dígitos.
- El DNI no puede repetirse en el repositorio temporal. El ID interno de un paciente es independiente del DNI.
- Una evaluación requiere paciente registrado, profesional y exactamente tres imágenes diferentes por contenido binario. Estas condiciones se comprueban también en dominio, no solo al habilitar botones.
- Cada conjunto corresponde a un paciente y un ojo seleccionado. La confirmación del usuario no constituye una verificación automática de que las fotos pertenezcan al mismo ojo.
- Cámara/galería comprueba que el archivo pueda decodificarse como imagen. No evalúa nitidez, iluminación, lesiones, calidad clínica ni cobertura.
- Preparar una evaluación no la guarda. El botón Guardar añade el registro al historial; repetir el guardado del mismo ID no lo duplica.
- Las listas y las imágenes expuestas por los repositorios/entidades no permiten modificar los registros desde las pantallas.
- Cerrar sesión limpia pacientes, evaluaciones y personal actual. Reiniciar el proceso también pierde los datos, ya que no hay persistencia.

Tres imágenes diferentes no garantizan tres campos clínicos adecuados. El protocolo de captura con teléfono y lente de 20D, campos requeridos y criterio de imagen no evaluable siguen pendientes de acuerdo y validación con el especialista.

## Recorridos y casos de uso

```text
Ingreso
  LoginScreen → AuthController → SignIn → AuthRepository
                                      → PreviewAuthRepository

Registro de paciente
  PatientFormScreen → PatientsController → RegisterPatient → PatientRepository
                                                           → InMemoryPatientRepository

Selección de una imagen
  CaptureScreen → CaptureController → SelectEvaluationImage
                                   → ImageAcquisitionRepository
                                   → DeviceImageRepository → image_picker
  La pantalla muestra la vista previa; el controlador conserva la foto si se acepta.

Preparación y guardado
  ReviewScreen → PreparationScreen → EvaluationsController → CreateEvaluation
                                                         → PatientRepository
  ResultScreen → EvaluationsController → SaveEvaluation → EvaluationRepository
                                                        → InMemoryEvaluationRepository
```

Los repositorios tienen contratos asíncronos para que la interfaz no tenga que cambiar su forma de invocarlos al conectar servicios. Eso no equivale a tener sincronización, recuperación tras fallos de red, caché persistente ni sesiones seguras implementadas.

## Qué cambió respecto a la estructura anterior

| Antes | Ahora |
|---|---|
| `screens/` con funcionalidades y varias vistas juntas | Páginas individuales en `features/<módulo>/presentation/pages/` |
| `models/` con paciente mezclado con datos de evaluación | Entidades separadas en el dominio de cada módulo |
| `DemoSession` con personal, pacientes y evaluaciones | Repositorios en memoria y controladores de cada funcionalidad, coordinados por `SessionController` |
| Acceso a `image_picker` desde la pantalla | Adaptador `DeviceImageRepository` tras un contrato de dominio |
| Navegación construida en cada pantalla | Rutas agrupadas en `app/router/app_routes.dart` |
| `ApiService` anterior para una imagen, sin uso | Retirado; el contrato de un backend real se definirá para la evaluación de tres imágenes |
| `theme/` y `widgets/` generales | Tema común en `core` y widgets generales en `shared`; widgets de evaluación dentro del módulo |

Se conserva la paleta verde, el logo del ojo, el menú lateral y los bloques claros del inicio. No se añadieron mensajes de demostración a la interfaz.

## Conexión con el sistema propuesto en la tesis

| Componente | Estado actual | Trabajo posterior |
|---|---|---|
| Flutter | Interfaces, navegación, reglas y datos temporales separados por capas | Implementar funcionalidades por casos de uso |
| Autenticación | Acceso de prueba; registro valida sin crear cuentas y recuperación sin servicio | Acordar servicio, credenciales, tokens y autorización |
| FastAPI | Sin cliente ni servidor implementado en esta etapa | Definir contrato de pacientes, evaluaciones, estados y errores |
| PostgreSQL | Sin conexión | Persistencia de identidades, evaluaciones y resultados mediante backend |
| Storage Bucket | Sin carga de archivos | Almacenar imágenes y asociarlas a posición, paciente y evaluación mediante backend |
| RETFound / PyTorch / ONNX Runtime | Sin ejecución ni pesos integrados | Seleccionar y validar modelo, procesamiento de múltiples vistas y calidad |
| Render | Propuesta del contexto | Evaluar y configurar despliegue cuando exista backend |

Para incorporar una implementación remota se añadirían adaptadores en `data`, con fuentes de datos y modelos de transporte cuando el contrato exista, y se conectarían en `AppDependencies`. Las reglas de dominio permanecen independientes del formato JSON y de la ubicación de los archivos. La persistencia requerirá también cargar registros al iniciar sesión, manejar errores de lectura y definir qué información se conserva al salir; el cierre actual elimina exclusivamente registros temporales.

La inferencia tendrá su propio caso de uso y contrato cuando se defina su comportamiento. No se dejó un endpoint ficticio ni un resultado fabricado. Las tres imágenes deberán asociarse a una única evaluación del ojo y a una versión del modelo.

TDT, TAP y PCD son indicadores del estudio y no se calculan en las estadísticas actuales. El conteo visual de pacientes/evaluaciones no equivale a esos indicadores. TAP requiere medir desde inicio del tamizaje hasta comunicación del resultado, no solo el tiempo de inferencia. Los 60 participantes descritos en el contexto no se asumen como conjunto de entrenamiento.

## Verificación y mantenimiento

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Las pruebas cubren navegación y formularios, flujo de tres imágenes, cancelación/reemplazo, rechazo de duplicados, confirmación, resultado pendiente y guardado explícito. Las pruebas de reglas cubren conjuntos incompletos, separación de paciente/ojo, invariantes de resultado, guardado sin duplicados y limpieza de sesión.

`test/architecture/dependency_rules_test.dart` verifica las fronteras principales: dominio sin Flutter o infraestructura, presentación sin acceso directo a datos/cámara/HTTP y datos sin presentación. Es una protección automática de imports, no una auditoría completa de arquitectura.

La cámara y sus permisos requieren una prueba adicional en un teléfono real. Las pruebas con repositorios inyectados no certifican el montaje óptico ni el comportamiento de dispositivos específicos.

## Diseño relacional preparado posteriormente

Se añadió en la raíz del repositorio `supabase/migrations/20261102130000_initial_schema.sql` con las tablas, restricciones y políticas de acceso para Supabase. El diseño incluye profesionales con expedientes privados y una cuenta administradora con consulta global. Las relaciones y la normalización se explican en [`../../docs/DATABASE.md`](../../docs/DATABASE.md).

Ambas migraciones fueron aplicadas al proyecto alojado el 2 de noviembre de 2026.

## Integración Supabase (2 de noviembre de 2026)

`main → AppBootstrap → AppDependencies.remote → AuthGate` inicia la aplicación. `AppConfig` admite únicamente URL HTTPS y clave pública. `AuthLinkCoordinator` procesa los retornos de confirmación/recuperación PKCE. `SessionController` restaura la identidad y carga repositorios, descartando datos locales al cerrar sesión.

`SupabaseAuthRepository`, `SupabasePatientRepository` y `SupabaseEvaluationRepository` implementan contratos del dominio. Los controladores y pantallas no importan Supabase. Los pacientes se pueden consultar y editar; el administrador tiene gestión global de expedientes y cuentas. El rol procede de `profiles`, nunca de metadatos editables del cliente. RLS garantiza el aislamiento en la base de datos.

Los borradores usan la RPC transaccional `save_evaluation_draft`, definida en la segunda migración. Guardan paciente, ojo, observaciones y tres metadatos (posición, hash, tipo, tamaño). Las fotos locales se mantienen solo durante la sesión; el bucket queda pendiente. El estado `draft` evita indicar que están cargadas o listas para inferencia.

La configuración pública local está excluida de Git. Google permanece desactivado hasta configurar OAuth. La URL de retorno ya está configurada y la confirmación de correo permanece activa. Para destinatarios externos falta SMTP. Auth y lecturas se comprobaron contra Supabase; correo y captura requieren validación completa en teléfono.

Las implementaciones en memoria permanecen como dobles explícitos de pruebas; no hay sustitución automática cuando Supabase falla. Ver configuración y ejecución actuales en [README](../README.md).

## Administración 1.1.0

El módulo `features/admin` añade contratos, casos de uso, adaptadores y pantallas exclusivas, inyectados en `SessionController`. La tercera migración incorpora activación de perfiles, RPC administrativas y auditoría. El alcance vigente y la verificación se detallan en [ADMINISTRATION.md](../../docs/ADMINISTRATION.md). Las referencias anteriores a administrador de solo consulta describen la versión inicial y quedan sustituidas por esta ampliación.

## Cloudflare R2 y FastAPI en Render (activo, 5 de noviembre de 2026)

La elección de Cloudflare R2 sustituye la propuesta de Supabase Storage. FastAPI autoriza mediante Supabase y sube los originales verificados a R2; devuelve enlaces GET temporales al consultar imágenes. Está desplegado como Web Service en Render Free. Las cuentas y los datos estructurados siguen usando Supabase. El modelo permanece pendiente. La configuración local contiene `IMAGE_API_URL=https://retinazo-images.onrender.com`. `SupabaseEvaluationRepository` guarda primero el borrador y después solicita la carga a `ImageApiClient`; `loadImages` recupera las fotos al consultar el historial. El dominio no depende de HTTP ni Supabase. Se comprobaron permisos, persistencia e integridad contra los servicios alojados con cuentas y PNG sintéticos; el teléfono físico sigue pendiente. Ver [R2_STORAGE.md](../../docs/R2_STORAGE.md).
