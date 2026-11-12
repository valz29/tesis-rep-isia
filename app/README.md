# Retinazo

Aplicación Flutter organizada con Clean Architecture por funcionalidad, con la identidad verde y el flujo de tres imágenes del mismo ojo.

## Estado al 12 de noviembre de 2026 · versión 1.3.1

Implementado en código: acceso por correo y contraseña, registro con confirmación, recuperación de contraseña, restauración de sesión, pacientes con creación/edición, búsqueda, historial y borradores de evaluación. Los adaptadores usan Supabase y las políticas SQL separan expedientes por profesional; el administrador gestiona todos los expedientes y las cuentas.

Se creó el proyecto Supabase Retinazo y se aplicaron las cinco migraciones. La cuenta administradora inicial está creada y verificada. Se comprobaron contra el servicio alojado el inicio de sesión, el rol protegido, las lecturas autorizadas, el rechazo de acceso anónimo y el bloqueo de cambios directos de rol y la gestión exclusiva mediante RPC autorizada. La validación completa en teléfono físico, incluidos enlaces de correo y cámara, sigue pendiente.

FastAPI está publicado en Render y guarda los originales en el bucket R2. Al guardar una evaluación se envían sus tres fotos; el historial puede recuperarlas desde la nube. El recorrido remoto se validó con PNG y cuentas sintéticas, incluyendo permisos y limpieza de datos de prueba. Los borradores anteriores que solo guardaron metadatos no adquieren fotos automáticamente. El modelo sigue pendiente; no se inventan grados ni confianza.

Google está implementado como opción de acceso, desactivada hasta configurar el proveedor OAuth. El correo integrado de Supabase solo entrega a miembros del equipo y tiene un límite actual de dos mensajes por hora; para usuarios externos hace falta SMTP propio.

Ver [administración y registro confirmado](../docs/ADMINISTRATION.md) para el alcance de Retinazo 1.3.0, las restricciones, pruebas y funciones por rol.

Los pacientes solo se asignan a profesionales activos con correo confirmado. El administrador debe seleccionar un profesional al registrarlos y puede desactivar/reactivar sus expedientes con motivo y auditoría. Los pacientes desactivados conservan su historial, pero no admiten nuevas evaluaciones o cargas. No se ofrece borrado de pacientes desde la app.

## Estructura

```text
lib/
  app/            Arranque, configuración, inyección, sesión y navegación
  core/           Errores, traducción de fallos de infraestructura y tema
  shared/         Widgets comunes
  features/
    auth/         domain / data / presentation
    patients/     domain / data / presentation
    evaluations/  domain / data / presentation
    admin/        domain / data / presentation
    home/         presentation
```

`main.dart` inicia `AppBootstrap`, que valida la configuración y crea `AppDependencies.remote`. Los contratos del dominio no dependen de Supabase. Los repositorios en memoria se conservan para pruebas con inyección explícita; el arranque de producción nunca cambia a ellos si falla la conexión. Cerrar sesión limpia tokens y caché local, conservando los registros remotos.

Consulta [organización del código](../docs/CODE_ORGANIZATION.md), [arquitectura](docs/ARCHITECTURE.md), [base de datos](../docs/DATABASE.md) y [activación del esquema](../supabase/README.md).

## Ejecutar y verificar

Copia `config/supabase.example.json` a `config/supabase.local.json` y completa URL de Supabase, clave pública e `IMAGE_API_URL=https://retinazo-images.onrender.com`. El archivo local está excluido de Git. Nunca incluyas contraseñas o claves de servidor en Flutter.

```sh
flutter pub get
flutter run --dart-define-from-file=config/supabase.local.json
flutter analyze
flutter test
flutter build apk --release --dart-define-from-file=config/supabase.local.json
```

APK: `build/app/outputs/flutter-apk/app-release.apk`. Android utiliza firma de desarrollo para instalaciones de prueba. iOS y captura en teléfono físico aún requieren validación.

En Supabase ya está configurado `com.devloop.retinazo://auth-callback/` como Site URL y retorno permitido de Auth. La confirmación de correo permanece activa. Los enlaces PKCE deben abrirse en el dispositivo donde se inició la solicitud.

Referencias: [retorno móvil](https://supabase.com/docs/guides/auth/native-mobile-deep-linking) y [SMTP](https://supabase.com/docs/guides/auth/auth-smtp).

## Identidad visual

Nombre: Retinazo. Verde `#0F6B6B`, fondo `#F2F6F6`, tinta `#17292B`. Logo: `assets/branding/retinazo-eye.png`.

## Imágenes en R2: integración activa

Cloudflare R2 guarda los archivos y FastAPI en Render autoriza las operaciones. La configuración local contiene `IMAGE_API_URL=https://retinazo-images.onrender.com`. Guardar sube las tres fotos y el historial puede descargarlas después de reiniciar. La cuarta migración está aplicada. Render Free se suspende por inactividad; las solicitudes a la API permiten hasta tres minutos para tolerar la reactivación. La descarga directa de cada imagen mantiene un límite menor. Ver [R2_STORAGE.md](../docs/R2_STORAGE.md).

## Guardado e historial · 1.3.1

Guardar muestra progreso, bloquea envíos duplicados y vuelve al inicio únicamente después de confirmar la carga. Se consulta solo la evaluación guardada, sin recargar todo el historial. Un fallo conserva la pantalla para reintentar; un borrador no equivale a una carga confirmada.

El historial crea filas bajo demanda y recupera la primera foto autorizada sin abrir el detalle. Las miniaturas se reducen localmente y se conservan en una caché de sesión acotada; si fallan, ofrecen reintento. Los originales clínicos no se recomprimen ni se sustituyen. Al abrir captura se intenta preparar el servicio HTTP en segundo plano, sin mantenerlo despierto periódicamente.

Las esperas todavía dependen de la red, del tamaño de los originales y de la disponibilidad del alojamiento. La prueba física del APK en el teléfono del usuario sigue pendiente.
