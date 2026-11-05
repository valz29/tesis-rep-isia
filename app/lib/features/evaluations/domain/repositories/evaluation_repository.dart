import '../entities/evaluation.dart';
import '../entities/evaluation_image.dart';

abstract interface class EvaluationRepository {
  Future<List<Evaluation>> list();
  Future<void> save(Evaluation evaluation);
  Future<List<EvaluationImage>> loadImages(String evaluationId);
  Future<void> clear();
}
