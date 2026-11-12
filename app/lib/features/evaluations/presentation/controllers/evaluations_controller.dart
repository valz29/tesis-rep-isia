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
  bool _disposed = false;
  int _epoch = 0;
  bool busy = false;
  String? error;
  String? imageError;
  String? loadingImagesFor;
  EvaluationsController(this._repository, this._create, this._save);
  bool isSaved(String id) {
    final evaluation = byId(id);
    return evaluation != null && evaluation.status != EvaluationStatus.draft;
  }

  int countByEye(OjoEvaluado eye) =>
      _evaluations.where((e) => e.ojo == eye).length;
  int get imageCount =>
      _evaluations.fold(0, (count, e) => count + e.imageCount);
  Evaluation? byId(String id) {
    for (final e in _evaluations) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<void> load() async {
    final epoch = ++_epoch;
    try {
      final records = await _repository.list();
      if (_disposed || epoch != _epoch) return;
      _evaluations = records;
      error = null;
    } on AppFailure catch (e) {
      if (!_disposed && epoch == _epoch) error = e.message;
      rethrow;
    } finally {
      _notify();
    }
  }

  Future<Evaluation?> prepare(
    EvaluationDraft draft,
    List<EvaluationImage> images,
    String professionalId,
  ) async {
    if (busy) return null;
    busy = true;
    error = null;
    _notify();
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
      _notify();
    }
  }

  Future<bool> save(Evaluation evaluation) async {
    if (busy) return false;
    final epoch = _epoch;
    busy = true;
    error = null;
    _notify();
    try {
      final saved = await _save(evaluation);
      if (_disposed || epoch != _epoch) return false;
      _evaluations = List.unmodifiable([
        saved,
        ..._evaluations.where((record) => record.id != saved.id),
      ]);
      return true;
    } on AppFailure catch (e) {
      if (epoch == _epoch) error = e.message;
      return false;
    } catch (_) {
      if (epoch == _epoch) error = 'No se pudo guardar la evaluación';
      return false;
    } finally {
      if (epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> prepareImageService() => _repository.prepareImageService();

  Future<EvaluationImage?> loadThumbnail(String id) async {
    final evaluation = byId(id);
    if (_disposed || evaluation == null) return null;
    final epoch = _epoch;
    final preview = await _repository.loadThumbnail(evaluation);
    return _disposed || epoch != _epoch ? null : preview;
  }

  Future<void> loadImages(String id) async {
    if (loadingImagesFor != null) return;
    final epoch = _epoch;
    loadingImagesFor = id;
    imageError = null;
    _notify();
    try {
      final images = await _repository.loadImages(id);
      if (_disposed || epoch != _epoch) return;
      _evaluations = List.unmodifiable(
        _evaluations.map(
          (e) => e.id == id
              ? e.withImages(images)
              : e.imagesStored
              ? e.withImages(const [])
              : e,
        ),
      );
    } on AppFailure catch (e) {
      if (epoch == _epoch) imageError = e.message;
    } catch (_) {
      if (epoch == _epoch) imageError = 'No se pudieron recuperar las imágenes';
    } finally {
      if (epoch == _epoch) {
        loadingImagesFor = null;
        _notify();
      }
    }
  }

  Future<void> clear() async {
    _epoch++;
    imageError = null;
    loadingImagesFor = null;
    await _repository.clear();
    _evaluations = const [];
    busy = false;
    error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }
}
