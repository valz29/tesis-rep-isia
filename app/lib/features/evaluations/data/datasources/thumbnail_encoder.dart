import 'dart:ui' as ui;

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/evaluation_image.dart';

/// Produces a small in-memory preview without changing the clinical original.
Future<EvaluationImage> encodeThumbnail(EvaluationImage original) async {
  final codec = await ui.instantiateImageCodec(
    original.bytes,
    targetWidth: 128,
    allowUpscaling: false,
  );
  try {
    final frame = await codec.getNextFrame();
    try {
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const AppFailure('No se pudo preparar la miniatura');
      }
      return EvaluationImage(data.buffer.asUint8List());
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
