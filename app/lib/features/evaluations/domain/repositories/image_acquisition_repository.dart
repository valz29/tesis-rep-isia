import '../entities/evaluation_image.dart';

enum ImageOrigin { camera, gallery }

abstract interface class ImageAcquisitionRepository {
  /// Null means the user cancelled. Technical failures are mapped by the adapter.
  Future<EvaluationImage?> pick(ImageOrigin origin);
}
