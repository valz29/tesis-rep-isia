import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/evaluation_image.dart';
import '../../domain/repositories/image_acquisition_repository.dart';
import '../../domain/usecases/select_evaluation_image.dart';

class CaptureController extends ChangeNotifier {
  final SelectEvaluationImage _select;
  final List<EvaluationImage?> _slots = List.filled(3, null);
  bool busy = false;
  String? error;
  bool _disposed = false;
  CaptureController(this._select);
  List<EvaluationImage?> get slots => List.unmodifiable(_slots);
  List<EvaluationImage> get images =>
      _slots.whereType<EvaluationImage>().toList(growable: false);
  int get count => images.length;
  int get nextSlot => _slots.indexWhere((image) => image == null);
  Future<void> choose(
    int slot,
    ImageOrigin origin,
    Future<bool> Function(EvaluationImage) confirm,
  ) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final image = await _select(origin, [
        for (var i = 0; i < 3; i++)
          if (i != slot && _slots[i] != null) _slots[i]!,
      ]);
      if (_disposed || image == null) return;
      if (await confirm(image) && !_disposed) _slots[slot] = image;
    } on AppFailure catch (e) {
      if (!_disposed) error = e.message;
    } catch (_) {
      if (!_disposed) error = 'No se pudo seleccionar la imagen';
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void remove(int slot) {
    if (!busy) {
      _slots[slot] = null;
      error = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
