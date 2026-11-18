import 'package:rd_app/features/evaluations/domain/evaluation.dart';
import 'package:rd_app/features/evaluations/domain/evaluation_image.dart';
import 'package:rd_app/features/evaluations/domain/evaluation_repository.dart';

class InMemoryEvaluationRepository implements EvaluationRepository {
  final Map<String, Evaluation> _records = {};
  @override
  Future<List<Evaluation>> list() async =>
      List.unmodifiable(_records.values.toList().reversed);
  @override
  Future<Evaluation> save(Evaluation evaluation) async =>
      _records.putIfAbsent(evaluation.id, () => evaluation);

  @override
  Future<List<EvaluationImage>> loadImages(
    String evaluationId, {
    void Function(int index, EvaluationImage image)? onImage,
  }) async => _records[evaluationId]?.imagenes ?? const [];

  @override
  Future<EvaluationImage?> loadThumbnail(Evaluation evaluation) async =>
      evaluation.imagenes.firstOrNull;

  @override
  Future<void> prepareImageService() async {}

  @override
  Future<void> clear() async => _records.clear();
}
