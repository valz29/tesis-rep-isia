import 'image_api_client.dart';

import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_failures.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/detection_result.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/entities/evaluation_draft.dart';
import '../../domain/entities/evaluation_image.dart';
import '../../domain/entities/evaluation_image_metadata.dart';
import '../../domain/repositories/evaluation_repository.dart';

class SupabaseEvaluationRepository implements EvaluationRepository {
  final SupabaseClient _client;
  final Map<String, List<EvaluationImage>> _localImages = {};
  final ImageApiClient? imageApi;
  final Set<String> _storedCache = {};
  int _generation = 0;
  SupabaseEvaluationRepository(this._client, {this.imageApi});
  @override
  Future<List<Evaluation>> list() async {
    try {
      final rows = await _client
          .from('evaluations')
          .select(
            '*,evaluation_images(*),results(*,model_versions(model_name,version))',
          )
          .order('created_at', ascending: false);
      return List.unmodifiable(
        rows.map((row) {
          final metadata =
              (row['evaluation_images'] as List)
                  .cast<Map<String, dynamic>>()
                  .map(
                    (m) => EvaluationImageMetadata(
                      position: (m['position'] as num).toInt(),
                      sha256: m['sha256'] as String,
                      contentType: m['content_type'] as String,
                      byteSize: (m['byte_size'] as num).toInt(),
                      uploaded:
                          m['upload_status'] == 'uploaded' &&
                          m['storage_provider'] == 'cloudflare_r2',
                    ),
                  )
                  .toList()
                ..sort((a, b) => a.position.compareTo(b.position));
          final raw = row['results'];
          final result = raw is Map<String, dynamic> ? raw : null;
          final version = result?['model_versions'] as Map<String, dynamic>?;
          return Evaluation(
            id: row['id'] as String,
            patientId: row['patient_id'] as String,
            professionalId: row['professional_id'] as String,
            ojo: row['eye'] == 'right'
                ? OjoEvaluado.derecho
                : OjoEvaluado.izquierdo,
            observaciones: row['observations'] as String?,
            imagenes: _localImages[row['id']] ?? const [],
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
                    modelVersion:
                        '${version?['model_name']} ${version?['version']}',
                  ),
          );
        }),
      );
    } catch (e) {
      throw supabaseFailure(e, 'No se pudo cargar el historial');
    }
  }

  @override
  Future<void> save(Evaluation evaluation) async {
    final generation = _generation;
    try {
      if (evaluation.imagenes.length != 3) {
        throw const AppFailure('Selecciona las tres imágenes para guardar');
      }
      final metadata = <Map<String, dynamic>>[];
      for (var i = 0; i < 3; i++) {
        final bytes = evaluation.imagenes[i].bytes;
        final type = lookupMimeType('', headerBytes: bytes);
        if (type == null || !type.startsWith('image/')) {
          throw const AppFailure('El formato de una imagen no está admitido');
        }
        metadata.add({
          'position': i + 1,
          'sha256': sha256.convert(bytes).toString(),
          'content_type': type,
          'byte_size': bytes.length,
        });
      }
      await _client.rpc(
        'save_evaluation_draft',
        params: {
          'evaluation_id_input': evaluation.id,
          'patient_id_input': evaluation.patientId,
          'eye_input': evaluation.ojo == OjoEvaluado.derecho ? 'right' : 'left',
          'observations_input': evaluation.observaciones,
          'images_input': metadata,
        },
      );
      if (generation != _generation) return;
      _localImages[evaluation.id] = evaluation.imagenes;
      if (imageApi != null) {
        await imageApi!.upload(evaluation.id, evaluation.imagenes);
        if (generation == _generation) {
          _rememberStored(evaluation.id, evaluation.imagenes);
        }
      }
    } catch (e) {
      throw supabaseFailure(e, 'No se pudo guardar la evaluación');
    }
  }

  void _rememberStored(String id, List<EvaluationImage> images) {
    _localImages[id] = images;
    _storedCache.remove(id);
    _storedCache.add(id);
    while (_storedCache.length > 3) {
      final oldest = _storedCache.first;
      _storedCache.remove(oldest);
      _localImages.remove(oldest);
    }
  }

  @override
  Future<List<EvaluationImage>> loadImages(String evaluationId) async {
    if (imageApi == null) {
      throw const AppFailure(
        'El servicio de imágenes R2 todavía no está configurado',
      );
    }
    final generation = _generation;
    final records = await list();
    final matches = records.where((e) => e.id == evaluationId);
    if (matches.isEmpty) {
      throw const AppFailure('La evaluación ya no está disponible');
    }
    final images = await imageApi!.download(
      evaluationId,
      matches.first.imageMetadata,
    );
    if (generation != _generation) return const [];
    _rememberStored(evaluationId, images);
    return images;
  }

  @override
  Future<void> clear() async {
    _generation++;
    _localImages.clear();
    _storedCache.clear();
  }
}
