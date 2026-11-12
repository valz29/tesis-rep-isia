import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_failures.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/entities/evaluation_image.dart';
import '../../domain/repositories/evaluation_repository.dart';
import '../datasources/image_api_client.dart';
import '../models/evaluation_mapper.dart';

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
        rows.map(
          (row) => EvaluationMapper.fromJson(
            row,
            localImages: _localImages[row['id']] ?? const [],
          ),
        ),
      );
    } catch (e) {
      throw supabaseFailure(e, 'No se pudo cargar el historial');
    }
  }

  @override
  Future<void> save(Evaluation evaluation) async {
    final generation = _generation;
    try {
      await _client.rpc(
        'save_evaluation_draft',
        params: EvaluationMapper.draftParameters(evaluation),
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
