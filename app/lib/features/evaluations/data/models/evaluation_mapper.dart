import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/detection_result.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/entities/evaluation_draft.dart';
import '../../domain/entities/evaluation_image.dart';
import '../../domain/entities/evaluation_image_metadata.dart';

/// Translates Supabase rows and RPC payloads at the infrastructure boundary.
abstract final class EvaluationMapper {
  static Evaluation fromJson(
    Map<String, dynamic> row, {
    List<EvaluationImage> localImages = const [],
  }) {
    final metadata =
        (row['evaluation_images'] as List)
            .cast<Map<String, dynamic>>()
            .map(_imageMetadata)
            .toList()
          ..sort((first, second) => first.position.compareTo(second.position));
    final rawResult = row['results'];
    final result = rawResult is Map<String, dynamic> ? rawResult : null;
    final version = result?['model_versions'] as Map<String, dynamic>?;

    return Evaluation(
      id: row['id'] as String,
      patientId: row['patient_id'] as String,
      professionalId: row['professional_id'] as String,
      ojo: row['eye'] == 'right' ? OjoEvaluado.derecho : OjoEvaluado.izquierdo,
      observaciones: row['observations'] as String?,
      imagenes: localImages,
      imageMetadata: metadata,
      fecha: DateTime.parse(row['created_at'] as String).toLocal(),
      status: switch (row['status']) {
        'draft' => EvaluationStatus.draft,
        'pending_analysis' => EvaluationStatus.pendingAnalysis,
        'not_gradable' => EvaluationStatus.notGradable,
        'completed' => EvaluationStatus.completed,
        _ => throw const AppFailure('Estado de evaluación desconocido'),
      },
      result: result == null
          ? null
          : DetectionResult(
              gradoICDR: (result['icdr_grade'] as num).toInt(),
              confianza: (result['confidence'] as num?)?.toDouble(),
              modelVersion: '${version?['model_name']} ${version?['version']}',
            ),
    );
  }

  static EvaluationImageMetadata _imageMetadata(Map<String, dynamic> row) =>
      EvaluationImageMetadata(
        position: (row['position'] as num).toInt(),
        sha256: row['sha256'] as String,
        contentType: row['content_type'] as String,
        byteSize: (row['byte_size'] as num).toInt(),
        uploaded:
            row['upload_status'] == 'uploaded' &&
            row['storage_provider'] == 'cloudflare_r2',
      );

  static Map<String, dynamic> draftParameters(Evaluation evaluation) {
    if (evaluation.imagenes.length != 3) {
      throw const AppFailure('Selecciona las tres imágenes para guardar');
    }
    return {
      'evaluation_id_input': evaluation.id,
      'patient_id_input': evaluation.patientId,
      'eye_input': evaluation.ojo == OjoEvaluado.derecho ? 'right' : 'left',
      'observations_input': evaluation.observaciones,
      'images_input': [
        for (var index = 0; index < evaluation.imagenes.length; index++)
          _uploadMetadata(evaluation.imagenes[index], index + 1),
      ],
    };
  }

  static Map<String, dynamic> _uploadMetadata(
    EvaluationImage image,
    int position,
  ) {
    final bytes = image.bytes;
    final contentType = lookupMimeType('', headerBytes: bytes);
    if (contentType == null || !contentType.startsWith('image/')) {
      throw const AppFailure('El formato de una imagen no está admitido');
    }
    return {
      'position': position,
      'sha256': sha256.convert(bytes).toString(),
      'content_type': contentType,
      'byte_size': bytes.length,
    };
  }
}
