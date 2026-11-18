import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_failure.dart';
import '../../../core/supabase_failures.dart';
import '../domain/evaluation.dart';
import '../domain/evaluation_image.dart';
import '../domain/evaluation_repository.dart';
import 'evaluation_mapper.dart';
import 'image_api_client.dart';
import 'thumbnail_encoder.dart';

class SupabaseEvaluationRepository implements EvaluationRepository {
  final SupabaseClient _client;
  final Map<String, List<EvaluationImage>> _localImages = {};
  final ImageApiClient? imageApi;
  final Set<String> _storedCache = {};
  final Map<String, EvaluationImage> _thumbnails = {};
  final List<Future<void>> _thumbnailQueues = [Future.value(), Future.value()];
  final Map<String, Future<EvaluationImage?>> _pendingThumbnails = {};
  int _nextThumbnailQueue = 0;
  static const _columns =
      '*,evaluation_images(*),results(*,model_versions(model_name,version))';
  int _generation = 0;
  SupabaseEvaluationRepository(this._client, {this.imageApi});
  @override
  Future<List<Evaluation>> list() async {
    try {
      final rows = await _client
          .from('evaluations')
          .select(_columns)
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
  Future<Evaluation> save(Evaluation evaluation) async {
    final generation = _generation;
    try {
      if (imageApi == null) {
        throw const AppFailure('El servicio de imágenes no está configurado');
      }
      await _client.rpc(
        'save_evaluation_draft',
        params: EvaluationMapper.draftParameters(evaluation),
      );
      if (generation != _generation) {
        throw const AppFailure('La sesión cambió durante el guardado');
      }
      _localImages[evaluation.id] = evaluation.imagenes;
      await imageApi!.upload(evaluation.id, evaluation.imagenes);
      if (generation != _generation) {
        throw const AppFailure('La sesión cambió durante el guardado');
      }
      _rememberStored(evaluation.id, evaluation.imagenes);
      return await _findById(evaluation.id);
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
  Future<List<EvaluationImage>> loadImages(
    String evaluationId, {
    void Function(int index, EvaluationImage image)? onImage,
  }) async {
    if (imageApi == null) {
      throw const AppFailure(
        'El servicio de imágenes R2 todavía no está configurado',
      );
    }
    final generation = _generation;
    final evaluation = await _findById(evaluationId);
    final cached = _storedCache.contains(evaluationId)
        ? _localImages[evaluationId]
        : null;
    if (cached != null) {
      for (var index = 0; index < cached.length; index++) {
        onImage?.call(index, cached[index]);
      }
      return cached;
    }
    final images = await imageApi!.download(
      evaluationId,
      evaluation.imageMetadata,
      onImage: (index, image) {
        if (generation == _generation) onImage?.call(index, image);
      },
    );
    if (generation != _generation) return const [];
    _rememberStored(evaluationId, images);
    return images;
  }

  Future<Evaluation> _findById(String id) async {
    final row = await _client
        .from('evaluations')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw const AppFailure('La evaluación ya no está disponible');
    }
    return EvaluationMapper.fromJson(
      row,
      localImages: _localImages[id] ?? const [],
    );
  }

  @override
  Future<void> prepareImageService() async => imageApi?.prepare();

  @override
  Future<EvaluationImage?> loadThumbnail(Evaluation evaluation) {
    final cached = _thumbnails[evaluation.id];
    if (cached != null) return Future.value(cached);
    final pending = _pendingThumbnails[evaluation.id];
    if (pending != null) return pending;
    final generation = _generation;
    final lane = _nextThumbnailQueue++ % _thumbnailQueues.length;
    final result = _thumbnailQueues[lane].then((_) async {
      if (generation != _generation) return null;
      final local =
          evaluation.imagenes.firstOrNull ??
          _localImages[evaluation.id]?.firstOrNull;
      final original =
          local ??
          (evaluation.imagesStored && imageApi != null
              ? await imageApi!.downloadThumbnail(
                  evaluation.id,
                  evaluation.imageMetadata,
                )
              : null);
      if (original == null || generation != _generation) return null;
      final preview = await encodeThumbnail(original);
      if (generation != _generation) return null;
      _thumbnails[evaluation.id] = preview;
      while (_thumbnails.length > 40) {
        _thumbnails.remove(_thumbnails.keys.first);
      }
      return preview;
    });
    _pendingThumbnails[evaluation.id] = result;
    _thumbnailQueues[lane] = result
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() {
          if (generation == _generation) {
            _pendingThumbnails.remove(evaluation.id);
          }
        });
    return result;
  }

  @override
  Future<void> clear() async {
    _generation++;
    _localImages.clear();
    _storedCache.clear();
    _thumbnails.clear();
    _pendingThumbnails.clear();
    for (var i = 0; i < _thumbnailQueues.length; i++) {
      _thumbnailQueues[i] = Future.value();
    }
  }
}
