import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/evaluation_image.dart';
import '../../domain/repositories/image_acquisition_repository.dart';

class DeviceImageRepository implements ImageAcquisitionRepository {
  final ImagePicker _picker;
  DeviceImageRepository(this._picker);
  @override
  Future<EvaluationImage?> pick(ImageOrigin origin) async {
    try {
      final file = await _picker.pickImage(
        source: origin == ImageOrigin.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 32);
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      return EvaluationImage(bytes);
    } catch (_) {
      throw const AppFailure(
        'No se pudo abrir la imagen. Revisa el permiso de cámara o selecciona otra foto.',
      );
    }
  }
}
