# Administración y confirmación de correo — Retinazo 1.3.0

Actualización del 11 de noviembre de 2026: la quinta migración `20261111180000_patient_lifecycle.sql` separa administración de responsabilidad clínica. El administrador gestiona expedientes, pero no es responsable de pacientes ni autor de nuevas evaluaciones. Las autorías históricas se conservan. La validación integral desde un teléfono continúa pendiente.

## Roles y pantallas

| Función | Profesional | Administrador |
|---|---|---|
| Panel de inicio | Accesos a sus registros | Resumen global, usuarios, pacientes, evaluaciones, estadísticas y actividad |
| Registro y edición de pacientes | Sus pacientes activos | Todos los pacientes; al registrar debe elegir un profesional responsable |
| Nueva evaluación | Sus pacientes activos | No; es una función clínica del profesional |
| Historial | Sus pacientes | Todos los pacientes |
| Correcciones de evaluación | Borradores propios según permisos existentes | Observaciones; ojo solo mientras sea borrador |
| Reasignación de responsable | No | Solo a profesionales activos con correo confirmado |
| Desactivación/reactivación de paciente | No | Con motivo obligatorio al desactivar; se conservan evaluaciones e imágenes |
| Usuarios | Sin acceso | Buscar y paginar, ver nombre, correo, rol, activación, confirmación y pacientes a cargo |
| Gestión de cuentas | No | Editar nombre, rol y activación; eliminar solo sin expedientes ni evaluaciones como autor |
| Auditoría administrativa | No | Consultar actor, acción, registro y fecha |

El administrador no ve contraseñas, no confirma correos de otras personas ni modifica manualmente grados, confianza o versiones de predicción. El correo de una cuenta no se cambia desde este panel: requiere el flujo de verificación de su propietario. R2 está integrado mediante FastAPI en Render; el modelo sigue pendiente.

## Ciclo de vida del paciente

La lista muestra pacientes activos por defecto; el administrador puede abrir Desactivados. Desactivar registra fecha, actor y motivo sin borrar el expediente ni sus imágenes. Impide nuevas evaluaciones y cargas de archivos, pero mantiene la lectura autorizada del historial. La reactivación exige un profesional responsable activo con correo confirmado. No hay borrado de pacientes en la interfaz.

El selector de responsables usa `admin_eligible_professionals`, que filtra en el servidor antes de limitar resultados. Los administradores están excluidos tanto del selector como de las restricciones SQL. Para promover una cuenta profesional a administrador se deben reasignar antes sus pacientes; se conserva la autoría de sus evaluaciones históricas.

Los pacientes heredados de versiones que permitían asignar administradores no se borran automáticamente al aplicar la migración. Al desactivarlos se retira esa asignación inválida y quedan archivados sin responsable, hasta una reasignación explícita. La limpieza de datos existentes es una operación aparte y debe distinguir archivo reversible de eliminación definitiva.

La reasignación cambia quién puede acceder al expediente; conserva la autoría original de las evaluaciones. Puede fallar si el responsable elegido ya tiene otro paciente con el mismo DNI. Una cuenta con historia clínica se desactiva en lugar de borrarse. No se puede desactivar, eliminar o degradar la propia cuenta administradora. Para conceder el rol administrador se exige correo confirmado y una confirmación en la interfaz.

## Flujo de registro

1. La persona ingresa nombre, correo, contraseña y confirmación de contraseña.
2. Supabase crea una identidad **pendiente** y envía el enlace, si el servicio de correo lo permite. Que aparezca una identidad en Auth no significa que ya esté activada.
3. La aplicación muestra “Confirma tu correo para activar tu cuenta”; puede reenviar el enlace o volver al ingreso. No entra automáticamente al inicio.
4. Al abrir el enlace en el mismo teléfono, PKCE intercambia el código y Auth confirma el correo. Solo entonces se obtiene una sesión válida y se cargan los datos.
5. Si intenta ingresar antes, Auth y la app rechazan el acceso. RLS también exige correo confirmado y cuenta activa.

Una respuesta inesperada de registro que incluya sesión se descarta y se presenta como problema de configuración. La excepción inicial del administrador se realizó manualmente y no se usa en el registro público. Las cuentas desactivadas pierden el acceso remoto aun con un token aún vigente; los datos ya vistos en memoria se limpian al cerrar sesión o al detectar la invalidez de la cuenta durante la comprobación de sesión.

La configuración alojada se comprobó con `mailer_autoconfirm=false`. Solo existe la cuenta administradora en el proyecto en el momento de esta verificación; no se encontró otra cuenta para eliminar. Hay APK anteriores en el directorio original `rd_app` que usaban almacenamiento temporal. No debe confundirse su registro visual con una cuenta creada en Supabase.

**SMTP pendiente:** el servicio integrado solo envía a direcciones del equipo del proyecto, con límite actual de dos mensajes por hora. Para dar de alta profesionales externos hace falta configurar SMTP. No se desactiva la confirmación para evitar esta restricción. Referencias: [registro en Flutter](https://supabase.com/docs/reference/dart/auth-signup), [SMTP](https://supabase.com/docs/guides/auth/auth-smtp).

## Implementación y seguridad

El módulo `app/lib/features/admin/` separa dominio, datos y presentación. `AdminRepository` define las operaciones; `SupabaseAdminRepository` invoca RPC y traduce respuestas; `UpdateAdminAccount` valida los cambios; `AdminController` coordina solicitudes, búsquedas y limpieza de sesión. Las pantallas no importan Supabase. `AppDependencies` realiza la inyección.

Todas las RPC administrativas verifican el rol, la confirmación y la activación en el servidor. El APK solo contiene una clave pública. Los clientes no tienen permisos directos para escribir roles, activación, propietarios, auditoría o resultados. Las operaciones privilegiadas usan funciones con `search_path` vacío, parámetros limitados y ejecución anónima revocada. Las mutaciones de roles se serializan para evitar que cambios simultáneos eliminen al último administrador activo.

La auditoría registra IDs y acciones, sin duplicar DNI, historia clínica, contraseñas ni imágenes. El usuario no puede modificarla desde la API. Las correcciones clínicas del administrador generan eventos en la misma transacción.

## Verificación

- 41 pruebas de PostgreSQL temporal: aislamiento entre profesionales, correo pendiente, inactivación con token existente, funciones exclusivas, reasignación, auditoría y protección de cuentas/estados clínicos.
- 25 pruebas Flutter: contratos, navegación, edición, registro pendiente, descarte de sesión inesperada y panel exclusivo.
- `flutter analyze`: sin observaciones.
- Supabase real: acceso del administrador, lista de usuarios, resumen, auditoría y rechazo anónimo de RPC; confirmación de correo activada.
- `supabase/tests/hosted_admin_smoke.sql`: registro/edición de paciente, tres metadatos, corrección de evaluación, auditoría y bloqueo de autodegradación dentro de una transacción revertida. Resultado `rollback_ok=true`; sin registros de prueba persistentes.

No se probó entrega de correo a profesionales externos porque falta SMTP. El retorno móvil, la cámara y el uso completo requieren un teléfono físico.
