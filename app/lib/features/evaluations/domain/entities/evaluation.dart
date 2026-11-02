import '../../../../core/errors/app_failure.dart';
import 'evaluation_draft.dart';
import 'evaluation_image.dart';
import 'detection_result.dart';

enum EvaluationStatus { pendingAnalysis, notGradable, completed }

class Evaluation {
  final String id;
  final String patientId;
  final OjoEvaluado ojo;
  final String? observaciones;
  final List<EvaluationImage> imagenes;
  final DateTime fecha;
  final String professionalId;
  final EvaluationStatus status;
  final DetectionResult? result;

  Evaluation({
    required this.id,
    required this.patientId,
    required this.ojo,
    required List<EvaluationImage> imagenes,
    required this.fecha,
    required this.professionalId,
    this.observaciones,
    this.status = EvaluationStatus.pendingAnalysis,
    this.result,
  }) : imagenes = List.unmodifiable(imagenes) {
    if (id.isEmpty || patientId.isEmpty || professionalId.isEmpty) {
      throw const AppFailure('La evaluación requiere paciente y profesional');
    }
    if (imagenes.length != 3) {
      throw const AppFailure(
        'La evaluación requiere exactamente tres imágenes',
      );
    }
    for (var i = 0; i < imagenes.length; i++) {
      for (var j = i + 1; j < imagenes.length; j++) {
        if (imagenes[i].sameContent(imagenes[j])) {
          throw const AppFailure('Las tres imágenes deben ser diferentes');
        }
      }
    }
    if ((status == EvaluationStatus.completed) != (result != null)) {
      throw const AppFailure(
        'El estado de la evaluación no coincide con su resultado',
      );
    }
  }
}
