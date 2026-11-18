import 'package:flutter/foundation.dart';

import '../../../core/app_failure.dart';
import '../domain/create_evaluation.dart';
import '../domain/evaluation.dart';
import '../domain/evaluation_draft.dart';
import '../domain/evaluation_image.dart';
import '../domain/evaluation_repository.dart';
import '../domain/save_evaluation.dart';

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
  final Map<int, EvaluationImage> _arrivingImages = {};
  String? _arrivingEvaluation;
  int _imageRequest = 0;
  EvaluationImage? arrivingImage(String id, int index) =>
      _arrivingEvaluation == id ? _arrivingImages[index] : null;
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
    if (loadingImagesFor == id) return;
    final epoch = _epoch;
    final request = ++_imageRequest;
    _arrivingEvaluation = id;
    _arrivingImages.clear();
    loadingImagesFor = id;
    imageError = null;
    _notify();
    try {
      final images = await _repository.loadImages(
        id,
        onImage: (index, image) {
          if (_disposed || epoch != _epoch || request != _imageRequest) return;
          _arrivingImages[index] = image;
          _notify();
        },
      );
      if (_disposed || epoch != _epoch || request != _imageRequest) return;
      _arrivingImages.clear();
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
      if (!_disposed && epoch == _epoch && request == _imageRequest) {
        imageError = e.message;
      }
    } catch (_) {
      if (!_disposed && epoch == _epoch && request == _imageRequest) {
        imageError = 'No se pudieron recuperar las imágenes';
      }
    } finally {
      if (!_disposed && epoch == _epoch && request == _imageRequest) {
        loadingImagesFor = null;
        _notify();
      }
    }
  }

  Future<void> clear() async {
    _epoch++;
    imageError = null;
    loadingImagesFor = null;
    _imageRequest++;
    _arrivingEvaluation = null;
    _arrivingImages.clear();
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
