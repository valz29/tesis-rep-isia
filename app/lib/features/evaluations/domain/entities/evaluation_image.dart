import 'dart:typed_data';

import '../../../../core/errors/app_failure.dart';

/// Encoded image owned by the entity. No plugins or device file paths in domain.
class EvaluationImage {
  final Uint8List _bytes;
  EvaluationImage(Uint8List bytes)
    : _bytes = Uint8List.fromList(bytes).asUnmodifiableView() {
    if (_bytes.isEmpty) throw const AppFailure('La imagen está vacía');
  }
  Uint8List get bytes => _bytes;
  bool sameContent(EvaluationImage other) {
    if (_bytes.length != other._bytes.length) return false;
    for (var i = 0; i < _bytes.length; i++) {
      if (_bytes[i] != other._bytes[i]) return false;
    }
    return true;
  }
}
