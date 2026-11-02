import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/entities/evaluation_draft.dart';
import '../../domain/entities/evaluation_image.dart';
import '../../domain/repositories/evaluation_repository.dart';
import '../../domain/usecases/create_evaluation.dart';
import '../../domain/usecases/save_evaluation.dart';

class EvaluationsController extends ChangeNotifier {
  final EvaluationRepository _repository;
  final CreateEvaluation _create;
  final SaveEvaluation _save;
  List<Evaluation> _evaluations = const [];
  List<Evaluation> get evaluations => _evaluations;
  bool busy = false;
  String? error;
  EvaluationsController(this._repository, this._create, this._save);
  bool isSaved(String id) => _evaluations.any((e) => e.id == id);
  int countByEye(OjoEvaluado eye) =>
      _evaluations.where((e) => e.ojo == eye).length;
  int get imageCount =>
      _evaluations.fold(0, (count, e) => count + e.imagenes.length);
  Future<Evaluation?> prepare(
    EvaluationDraft draft,
    List<EvaluationImage> images,
    String professionalId,
  ) async {
    if (busy) return null;
    busy = true;
    error = null;
    notifyListeners();
    try {
      return await _create(draft, images, professionalId);
    } on AppFailure catch (e) {
      error = e.message;
      return null;
    } catch (_) {
      error = 'No se pudo preparar la evaluación';
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> save(Evaluation evaluation) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _save(evaluation);
      _evaluations = await _repository.list();
      return true;
    } on AppFailure catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'No se pudo guardar la evaluación';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    await _repository.clear();
    _evaluations = const [];
    error = null;
    notifyListeners();
  }
}
