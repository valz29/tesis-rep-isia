# Retinazo

Aplicación Flutter para el recorrido de evaluación de tres imágenes de un mismo ojo. El proyecto está organizado con Clean Architecture por funcionalidad y conserva la interfaz verde de Retinazo.

## Estado actual

- Bienvenida, acceso, registro visual y recuperación visual.
- Registro temporal de pacientes, búsqueda y selección del ojo.
- Selección de tres imágenes desde cámara/galería, vista previa, reemplazo, eliminación y confirmación conjunta.
- Preparación de la evaluación, resultado pendiente, guardado temporal, historial y conteos.
- Contratos de repositorios, casos de uso y controladores separados de las pantallas.

El ingreso acepta correo válido y contraseña de cuatro o más caracteres, sin verificar cuentas reales. Registrarse valida campos y vuelve al ingreso con el correo precargado, sin crear una cuenta. Recuperar acceso no envía correos.

Los datos e imágenes permanecen en memoria y se eliminan al cerrar sesión o reiniciar la aplicación. No hay backend, base de datos, subida de archivos ni modelo conectado. El selector del sistema puede crear archivos temporales propios. Las evaluaciones no presentan grados o confianza ficticios.

## Estructura

```text
lib/
  app/            Arranque, inyección, sesión y navegación
  core/           Errores comunes y tema
  shared/         Widgets generales
  features/
    auth/         domain / data / presentation
    patients/     domain / data / presentation
    evaluations/  domain / data / presentation
    home/         presentation
```

Cada módulo separa dominio, implementaciones de datos y presentación. `AppDependencies` conecta los repositorios actuales en memoria; el acceso a cámara/galería está aislado en un adaptador de datos.

Consulta [la explicación de arquitectura](docs/ARCHITECTURE.md) para ver responsabilidades, entidades, flujo de dependencias, cambios realizados y puntos de integración con el sistema propuesto en la tesis.

## Ejecutar y verificar

Con el SDK de Flutter disponible en el PATH:

```sh
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --release
```

APK generado: `build/app/outputs/flutter-apk/app-release.apk`. La configuración Android actual utiliza firma de desarrollo para instalación de pruebas.

Las pruebas verifican reglas y recorridos con dependencias inyectadas. La cámara, permisos y captura óptica necesitan validación en teléfono real.

## Identidad visual

Nombre visible: Retinazo. Paleta principal `#0F6B6B`, fondo `#F2F6F6` y tinta `#17292B`. Se conservan el menú lateral verde y los bloques claros con texto verde del inicio.

El logo está en `assets/branding/retinazo-eye.png`; el prompt de edición de la referencia del usuario se conserva en `assets/branding/logo-prompt.txt`.

## Próxima etapa

Persistencia, autenticación real e inferencia continúan pendientes. El contexto de tesis contempla FastAPI, PostgreSQL, un bucket de imágenes y un modelo basado en RETFound, todavía sin integrar. La reorganización no cierra las decisiones de protocolo clínico, entrenamiento, contrato del servidor o despliegue.
