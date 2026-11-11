# Base relacional de Retinazo

Estado al 11 de noviembre de 2026: cinco migraciones aplicadas en el proyecto Retinazo (`rxlceiknbabusicneykd`). Las primeras tres se aplicaron por SQL Editor; la cuarta y quinta por Management API. Ocho tablas con RLS, RPC de borradores, administración y confirmación de imágenes R2 comprobadas. Cuenta administradora inicial creada, verificada y probada mediante Auth y Data API con clave pública. Flutter integrado con el servicio de imágenes en Render. SMTP externo, Google OAuth y modelo pendientes.

No volver a ejecutar las migraciones iniciales en este proyecto: los cambios futuros requieren nuevas migraciones. No está vinculado al CLI. El historial remoto contiene las migraciones aplicadas por API, pero no las primeras tres aplicadas manualmente; antes de migrar a CLI habrá que reconciliar ese historial.

- Migración: `migrations/20261102130000_initial_schema.sql`.
- Diseño, diccionario, relaciones y normalización: [`../docs/DATABASE.md`](../docs/DATABASE.md).
- Pruebas: `python3 scripts/test_database.py`, desde la raíz del repositorio, con Docker disponible. La primera ejecución descarga la imagen oficial fijada por digest. El contenedor es temporal, sin puertos publicados ni datos reales.

La migración utiliza las tablas/funciones de Auth y los roles de PostgreSQL que Supabase ya proporciona. **No ejecutar `tests/auth_stub.sql` en Supabase**: es una sustitución mínima de Auth utilizada únicamente por las pruebas locales.

## Reproducir en otro proyecto vacío

1. Crear o abrir un proyecto nuevo vacío.
2. Revisar el SQL completo, en especial las reglas de acceso y unicidad de DNI por profesional.
3. Ejecutar en orden los cinco archivos de `migrations/` (esquema inicial, guardado de borradores, administración, R2 y ciclo de vida de pacientes) desde el SQL Editor dentro de una única transacción (`BEGIN;` antes y `COMMIT;` después). Conservar los archivos como historial. No ejecutar la misma creación dos veces: una modificación posterior debe ser otra migración.
4. Alternativamente, gestionar desde el inicio con Supabase CLI: inicializar la configuración, vincular el proyecto y aplicar las migraciones con `supabase db push`. Elegir un método de gestión para mantener el historial coherente; no aplicar por SQL Editor y después ejecutar a ciegas la misma migración por CLI.
5. Configurar el método de autenticación y su correo/retorno móvil en una etapa separada. Un usuario creado sin confirmar su correo ya puede tener un perfil, pero las políticas no le permiten acceder a los datos de la app.
6. Verificar el esquema y las políticas en el proyecto real antes de conectar Flutter. Las pruebas locales no sustituyen esa comprobación ni prueban entrega de correos u OAuth.

No se incluyen contraseñas ni claves del proyecto. La clave `service_role` es exclusivamente de servidor y no debe incorporarse al APK.

## Asignar tu cuenta administradora

Primero crearás y verificarás tu cuenta mediante Supabase Auth. Después, desde el SQL Editor con una sesión de administración, sustituirás el UUID del ejemplo por el ID real de tu usuario:

```sql
UPDATE public.profiles
SET role = 'admin'
WHERE id = 'UUID_REAL_DE_TU_USUARIO'
RETURNING id, full_name, role;
```

Debe devolver exactamente la cuenta elegida. No se asigna por un correo escrito en Flutter ni por `user_metadata`. Los registros nuevos siempre empiezan como `professional`, aunque el cliente intente enviar otro rol en sus metadatos.

La migración `20261102180000_admin_management.sql` amplía el administrador con gestión de cuentas, creación/edición de pacientes, reasignación, corrección de evaluaciones y auditoría. Ver [administración](../docs/ADMINISTRATION.md).

La tercera migración permite que un administrador sea autor de evaluaciones y responsable de pacientes. La reasignación de responsabilidad conserva las autorías históricas. No se puede desactivar o degradar la propia cuenta administradora.

## Imágenes y análisis

La tabla de imágenes almacena metadatos y referencias al bucket R2. No guarda archivos ni URLs públicas o temporales. Los borradores admiten de cero a tres filas de imagen; una evaluación solo sale de `draft` con tres imágenes marcadas como cargadas por el servidor.

SQL comprueba la coherencia de los metadatos, pero no puede comprobar que el objeto exista en un bucket. FastAPI valida los archivos y escribe en R2 antes de llamar a la RPC de confirmación. Una carga fallida conserva el borrador para reintentar; una foto local no equivale a un objeto confirmado.

Las tablas de versiones del modelo y resultados se crean vacías. Solo se carga el catálogo de cinco etiquetas ICDR. No se insertan predicciones de ejemplo en la migración.

Flutter utiliza los adaptadores Supabase en producción. `save_evaluation_draft` guarda evaluación y metadatos en una transacción idempotente. Cerrar sesión limpia tokens y fotos de la memoria, conservando registros remotos. La lectura remota y autenticación están comprobadas; las escrituras clínicas se validaron con PostgreSQL temporal y también con una transacción revertida en Supabase. Los adaptadores y pantallas se comprobaron con pruebas Flutter. El flujo completo en teléfono queda pendiente.

## Nota sobre el correo de pruebas

El servicio de correo integrado de Supabase tiene actualmente un límite de dos mensajes por hora y solo entrega a direcciones que pertenecen al equipo del proyecto. Tener pocos usuarios no habilita por sí solo el envío a otros destinatarios. Para altas de usuarios externos habrá que configurar SMTP propio. Esta configuración no se realiza con la migración de tablas.

Referencia: [SMTP de Supabase](https://supabase.com/docs/guides/auth/auth-smtp).

## Cuarta migración aplicada: Cloudflare R2

`20261105130000_r2_image_storage.sql` se aplicó por Management API el 5 de noviembre de 2026, después de comprobar que no existían referencias previas a archivos. Añade `storage_provider` y la RPC `finish_r2_upload`, ejecutable exclusivamente por el servidor. Se verificaron los permisos reales y el recorrido autenticado de carga/lectura mediante Render y R2 con cuentas y datos sintéticos; al finalizar no quedaron registros temporales. Ver [R2_STORAGE.md](../docs/R2_STORAGE.md).

## Quinta migración: responsabilidad profesional y pacientes desactivados

`20261111180000_patient_lifecycle.sql` está aplicada. Restringe responsables a profesionales activos confirmados, impide nuevas evaluaciones de administradores y añade desactivación/reactivación auditada de pacientes sin borrar historial o archivos. Los registros anteriores se conservan hasta decidir su archivo, reasignación o limpieza explícita. La desactivación de un paciente heredado a cargo de un administrador retira esa asignación y exige reasignar antes de reactivar. Las nuevas asignaciones a administradores se rechazan en SQL.
