import '../entities/evaluation.dart';

abstract interface class EvaluationRepository {
  Future<List<Evaluation>> list();
  Future<void> save(Evaluation evaluation);
  Future<void> clear();
}
