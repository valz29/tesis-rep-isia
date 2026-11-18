# Herramientas de desarrollo

Se ejecutan de forma explícita desde `app`. No se incluyen en el APK.

## Iconos

`dart run tool/generate_icons.dart` regenera los recursos nativos del logo.

## Video del flujo del profesional

`record_professional_flow_test.dart` usa las pantallas reales con repositorios locales, cuenta y paciente ficticios y tres ilustraciones generadas con Canvas. No llama a Supabase, Render, R2, cámara ni correo. La confirmación y el guardado son representaciones del recorrido; el modelo no se ejecuta. El video lleva esta indicación en sus rótulos.

```bash
flutter test tool/record_professional_flow_test.dart --no-pub \
  --dart-define=FLOW_FONT_DIR=/home/devloop307/sdkFlutter/flutter/bin/cache/artifacts/material_fonts \
  --dart-define=FLOW_OUTPUT_DIR=/tmp/retinazo-professional-flow

python3 tool/render_professional_video.py /tmp/retinazo-professional-flow \
  '/home/devloop307/Descargas/Retinazo - recorrido del profesional/Retinazo - flujo completo profesional.mp4'
```

Para ensayar los pasos sin capturar fotogramas, añadir `--dart-define=FLOW_RECORD=false` al primer comando. El guion con marcas de tiempo acompaña al MP4 y sus capítulos también se integran en el archivo. La codificación requiere FFmpeg; no requiere paquetes Python adicionales. Los fotogramas intermedios permanecen fuera del repositorio.
