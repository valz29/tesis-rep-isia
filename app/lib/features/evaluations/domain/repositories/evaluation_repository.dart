import '../entities/evaluation.dart';
import '../entities/evaluation_image.dart';

abstract interface class EvaluationRepository {
  Future<List<Evaluation>> list();
  Future<Evaluation> save(Evaluation evaluation);
  Future<List<EvaluationImage>> loadImages(String evaluationId);
  Future<EvaluationImage?> loadThumbnail(Evaluation evaluation);
  Future<void> prepareImageService();
  Future<void> clear();
}
