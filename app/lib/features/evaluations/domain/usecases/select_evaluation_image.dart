import '../../../../core/errors/app_failure.dart';
import '../entities/evaluation_image.dart';
import '../repositories/image_acquisition_repository.dart';

class SelectEvaluationImage {
  final ImageAcquisitionRepository _repository;
  const SelectEvaluationImage(this._repository);
  Future<EvaluationImage?> call(
    ImageOrigin origin,
    Iterable<EvaluationImage> otherImages,
  ) async {
    final image = await _repository.pick(origin);
    if (image != null && otherImages.any((other) => other.sameContent(image))) {
      throw const AppFailure(
        'Esta imagen ya está seleccionada. Elige una toma diferente.',
      );
    }
    return image;
  }
}
