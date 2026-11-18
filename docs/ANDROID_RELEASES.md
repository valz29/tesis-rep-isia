# Distribución Android de Retinazo

La versión 1.3.6+10 inicia la distribución con una firma permanente. Cada actualización debe conservar el identificador `com.devloop.rd_app`, utilizar la misma clave y aumentar el número situado después de `+` en `app/pubspec.yaml`.

## Firma y respaldo

La configuración de Gradle carga `RETINAZO_SIGNING_PROPERTIES` o, si no se define, `app/android/key.properties`. El archivo privado contiene `storeFile` (ruta absoluta al almacén), `storePassword`, `keyAlias` y `keyPassword`. La plantilla pública `app/android/key.properties.example` solo muestra los nombres necesarios.

En el equipo del propietario, el almacén PKCS12 y la configuración se guardan en `~/.local/share/retinazo/signing/`, fuera del repositorio, con permisos restringidos. Deben respaldarse juntos en un lugar privado y separado del equipo. Perder la clave impide actualizar las instalaciones firmadas con ella. No enviar estos archivos a GitHub ni a los usuarios.

El modo release falla si falta la configuración; no vuelve a la firma de depuración. Las compilaciones debug conservan su funcionamiento habitual.

## Construcción

Desde `app/`, preparar `config/supabase.local.json` con URL de Supabase, clave pública y URL de FastAPI. Las claves de servidor, R2 y administración nunca pertenecen al cliente móvil.

```bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
./tool/build_release.sh
```

El script utiliza por defecto la ubicación privada indicada. Se puede seleccionar otro archivo mediante `RETINAZO_SIGNING_PROPERTIES`, otra configuración de servicios con `RETINAZO_CONFIG_FILE` y otra instalación de Flutter con `FLUTTER_BIN`. El APK resultante es `app/build/app/outputs/flutter-apk/app-release.apk` desde la raíz del repositorio.

Antes de publicar, comprobar firma y certificado con `apksigner verify --verbose --print-certs`, identificador y versión con `aapt dump badging`, y calcular SHA-256 del archivo. El commit etiquetado debe contener el código usado para compilar. Los archivos locales de configuración se excluyen de Git; solo contienen configuración pública del cliente.

## Publicación y enlace fijo

Crear una etiqueta `v1.3.6` sobre el commit verificado y una GitHub Release asociada a ella. Adjuntar el APK con el nombre estable `retinazo.apk`, `SHA256SUMS`, el QR y un manifiesto público de versión con el commit y la huella del certificado. Publicar como versión más reciente después de cargar todos los archivos.

Enlace para compartir y codificar en el QR:

<https://github.com/valz29/tesis-rep-isia/releases/latest/download/retinazo.apk>

Este enlace redirige al archivo del mismo nombre en la última release estable. Las siguientes versiones deben conservar ese nombre. GitHub no instala ni actualiza automáticamente la app: el usuario descarga el APK y confirma su instalación en Android. La disponibilidad del enlace debe comprobarse tras cada publicación, descargando el archivo y comparando su SHA-256.

## Primera instalación y límites

Los APK anteriores usaban la firma de depuración. Android no permite sustituirlos directamente por la versión con otra firma. Para el primer cambio es necesario desinstalar el anterior e instalar el nuevo; esto elimina la sesión y los datos locales de la app. Los registros remotos permanecen en los servicios alojados y se recuperan al volver a ingresar. Las evaluaciones o imágenes que solo existan localmente deben guardarse antes de desinstalar.

Las siguientes actualizaciones firmadas con esta misma clave podrán instalarse encima, siempre que aumente el número de compilación. Esta distribución es por descarga directa; no publica en Google Play. El modelo de análisis continúa pendiente y esta release no añade diagnósticos ni resultados clínicos. La instalación y los gestos en un teléfono físico requieren validación en ese dispositivo.
