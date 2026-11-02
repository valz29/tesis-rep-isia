import '../../domain/entities/evaluation.dart';
import '../../domain/repositories/evaluation_repository.dart';

class InMemoryEvaluationRepository implements EvaluationRepository {
  final Map<String, Evaluation> _records = {};
  @override
  Future<List<Evaluation>> list() async =>
      List.unmodifiable(_records.values.toList().reversed);
  @override
  Future<void> save(Evaluation evaluation) async {
    _records.putIfAbsent(evaluation.id, () => evaluation);
  }

  @override
  Future<void> clear() async => _records.clear();
}
