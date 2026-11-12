import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rd_app/features/evaluations/data/datasources/image_api_client.dart';
import 'package:rd_app/features/evaluations/data/models/evaluation_mapper.dart';
import 'package:rd_app/features/evaluations/data/repositories/supabase_evaluation_repository.dart';
import 'package:rd_app/features/evaluations/domain/entities/evaluation.dart';
import 'package:rd_app/features/evaluations/domain/entities/evaluation_draft.dart';
import 'package:rd_app/features/evaluations/domain/entities/evaluation_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fixtures.dart';

const evaluationId = '30000000-0000-0000-0000-000000000001';

Map<String, dynamic> storedRow() => {
  'id': evaluationId,
  'patient_id': patient.id,
  'professional_id': patient.ownerId,
  'eye': 'right',
  'status': 'pending_analysis',
  'created_at': '2026-11-12T12:00:00Z',
  'results': null,
  'evaluation_images': [
    for (var n = 1; n <= 3; n++)
      {
        'position': n,
        'sha256': sha256.convert(photo(n)).toString(),
        'content_type': 'image/png',
        'byte_size': photo(n).length,
        'upload_status': 'uploaded',
        'storage_provider': 'cloudflare_r2',
      },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Successful save reads only the saved record and returns its confirmed storage status', () async {
    var queries = 0;
    var uploads = 0;
    final database = SupabaseClient(
      'https://example.invalid',
      'sb_publishable_test',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/rpc/save_evaluation_draft')) {
          final parameters = jsonDecode(request.body) as Map;
          expect(parameters['evaluation_id_input'], evaluationId);
          expect(parameters['images_input'], hasLength(3));
          return http.Response(jsonEncode(evaluationId), 200, request: request);
        }
        queries++;
        expect(request.url.queryParameters['id'], 'eq.$evaluationId');
        expect(request.url.queryParameters.containsKey('order'), isFalse);
        return http.Response(jsonEncode([storedRow()]), 200, request: request);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(database.dispose);
    final transport = MockClient((request) async {
      uploads++;
      expect(request.method, 'PUT');
      return http.Response('', 204);
    });
    addTearDown(transport.close);
    final repository = SupabaseEvaluationRepository(
      database,
      imageApi: ImageApiClient(
        Uri.parse('https://images.example.invalid'),
        () => 'synthetic',
        transport: transport,
      ),
    );
    final saved = await repository.save(
      Evaluation(
        id: evaluationId,
        patientId: patient.id,
        professionalId: patient.ownerId!,
        ojo: OjoEvaluado.derecho,
        fecha: DateTime(2026, 11, 12),
        status: EvaluationStatus.draft,
        imagenes: [for (var n = 1; n <= 3; n++) EvaluationImage(photo(n))],
      ),
    );
    expect(saved.imagesStored, isTrue);
    expect(saved.status, EvaluationStatus.pendingAnalysis);
    expect(saved.imagenes, hasLength(3));
    expect(queries, 1);
    expect(uploads, 1);
  });

  test(
    'Preview queue caches small images and clears them when the session ends',
    () async {
      var imageDownloads = 0;
      final database = SupabaseClient(
        'https://example.invalid',
        'sb_publishable_test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(database.dispose);
      final transport = MockClient((request) async {
        if (request.url.host == 'images.example.invalid') {
          return http.Response(
            jsonEncode({
              'images': [
                for (var n = 1; n <= 3; n++)
                  {
                    'position': n,
                    'url': 'https://account.r2.cloudflarestorage.com/image-$n',
                  },
              ],
            }),
            200,
          );
        }
        imageDownloads++;
        expect(request.url.path, '/image-1');
        return http.Response.bytes(photo(1), 200);
      });
      addTearDown(transport.close);
      final repository = SupabaseEvaluationRepository(
        database,
        imageApi: ImageApiClient(
          Uri.parse('https://images.example.invalid'),
          () => 'synthetic',
          transport: transport,
        ),
      );
      final evaluation = EvaluationMapper.fromJson(storedRow());
      final previews = await Future.wait([
        repository.loadThumbnail(evaluation),
        repository.loadThumbnail(evaluation),
      ]);
      expect(previews.every((preview) => preview != null), isTrue);
      expect(imageDownloads, 1);
      expect(identical(previews.first, previews.last), isTrue);
      await repository.clear();
      expect(await repository.loadThumbnail(evaluation), isNotNull);
      expect(imageDownloads, 2);
    },
  );
}
