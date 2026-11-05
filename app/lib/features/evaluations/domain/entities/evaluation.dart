import '../../../../core/errors/app_failure.dart';
import 'evaluation_draft.dart';
import 'evaluation_image.dart';
import 'detection_result.dart';
import 'evaluation_image_metadata.dart';

enum EvaluationStatus { draft, pendingAnalysis, notGradable, completed }

class Evaluation {
  final String id;
  final String patientId;
  final OjoEvaluado ojo;
  final String? observaciones;
  final List<EvaluationImage> imagenes;
  final List<EvaluationImageMetadata> imageMetadata;
  int get imageCount =>
      imagenes.isNotEmpty ? imagenes.length : imageMetadata.length;
  bool get imagesStored =>
      imageMetadata.length == 3 && imageMetadata.every((m) => m.uploaded);
  Evaluation withImages(List<EvaluationImage> images) => Evaluation(
    id: id,
    patientId: patientId,
    ojo: ojo,
    imagenes: images,
    fecha: fecha,
    professionalId: professionalId,
    observaciones: observaciones,
    status: status,
    result: result,
    imageMetadata: imageMetadata,
  );
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
    List<EvaluationImageMetadata> imageMetadata = const [],
  }) : imagenes = List.unmodifiable(imagenes),
       imageMetadata = List.unmodifiable(imageMetadata) {
    if (id.isEmpty || patientId.isEmpty || professionalId.isEmpty) {
      throw const AppFailure('La evaluación requiere paciente y profesional');
    }
    if ((imagenes.isNotEmpty && imagenes.length != 3) ||
        (imagenes.isEmpty &&
            this.imageMetadata.length != 3 &&
            status != EvaluationStatus.draft) ||
        this.imageMetadata.length > 3) {
      throw const AppFailure(
        'La evaluación requiere exactamente tres imágenes',
      );
    }
    if (this.imageMetadata.map((m) => m.position).toSet().length !=
            this.imageMetadata.length ||
        this.imageMetadata.map((m) => m.sha256).toSet().length !=
            this.imageMetadata.length ||
        this.imageMetadata.any(
          (m) =>
              m.position < 1 ||
              m.position > 3 ||
              !RegExp(r'^[0-9a-f]{64}$').hasMatch(m.sha256) ||
              m.byteSize <= 0,
        )) {
      throw const AppFailure('Los metadatos de imágenes no son válidos');
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
