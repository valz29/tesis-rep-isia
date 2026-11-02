import '../../../../core/errors/app_failure.dart';

/// ICDR prediction, distinct from an ungradable evaluation and from study metrics.
class DetectionResult {
  final int gradoICDR;
  final double? confianza;
  final String modelVersion;
  DetectionResult({
    required this.gradoICDR,
    this.confianza,
    required this.modelVersion,
  }) {
    if (gradoICDR < 0 ||
        gradoICDR > 4 ||
        modelVersion.trim().isEmpty ||
        (confianza != null &&
            (!confianza!.isFinite || confianza! < 0 || confianza! > 1))) {
      throw const AppFailure('El resultado de clasificación no es válido');
    }
  }
}
