import 'evaluation.dart';
import 'evaluation_image.dart';

abstract interface class EvaluationRepository {
  Future<List<Evaluation>> list();
  Future<Evaluation> save(Evaluation evaluation);
  Future<List<EvaluationImage>> loadImages(
    String evaluationId, {
    void Function(int index, EvaluationImage image)? onImage,
  });
  Future<EvaluationImage?> loadThumbnail(Evaluation evaluation);
  Future<void> prepareImageService();
  Future<void> clear();
}
