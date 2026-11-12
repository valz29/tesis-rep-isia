import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:rd_app/core/errors/app_failure.dart';
import 'package:rd_app/features/evaluations/data/models/evaluation_mapper.dart';
import 'package:rd_app/features/evaluations/domain/entities/evaluation.dart';
import 'package:rd_app/features/evaluations/domain/entities/evaluation_draft.dart';
import 'package:rd_app/features/evaluations/domain/entities/evaluation_image.dart';

import '../../support/fixtures.dart';

Map<String, dynamic> storedEvaluation() => {
  'id': 'evaluation',
  'patient_id': 'patient',
  'professional_id': 'professional',
  'eye': 'left',
  'observations': 'Seguimiento',
  'status': 'completed',
  'created_at': '2026-11-12T12:00:00Z',
  'evaluation_images': [
    for (final position in [3, 1, 2])
      {
        'position': position,
        'sha256': sha256.convert(photo(position)).toString(),
        'content_type': 'image/png',
        'byte_size': photo(position).length,
        'upload_status': 'uploaded',
        'storage_provider': 'cloudflare_r2',
      },
  ],
  'results': {
    'icdr_grade': 0,
    'confidence': 0.91,
    'model_versions': {'model_name': 'Synthetic', 'version': 'test'},
  },
};

void main() {
  test('Stored evaluation preserves eye, author, order and grade zero', () {
    final evaluation = EvaluationMapper.fromJson(storedEvaluation());
    expect(evaluation.ojo, OjoEvaluado.izquierdo);
    expect(evaluation.professionalId, 'professional');
    expect(evaluation.imageMetadata.map((image) => image.position), [1, 2, 3]);
    expect(evaluation.imagesStored, isTrue);
    expect(evaluation.imagenes, isEmpty);
    expect(evaluation.result!.gradoICDR, 0);
    expect(evaluation.result!.confianza, 0.91);
    expect(evaluation.result!.modelVersion, 'Synthetic test');
  });

  test(
    'Draft payload carries three hashes without privileged result fields',
    () {
      final evaluation = Evaluation(
        id: 'evaluation',
        patientId: 'patient',
        professionalId: 'professional',
        ojo: OjoEvaluado.izquierdo,
        imagenes: [
          for (var position = 1; position <= 3; position++)
            EvaluationImage(photo(position)),
        ],
        fecha: DateTime(2026, 11, 12),
        status: EvaluationStatus.draft,
      );
      final payload = EvaluationMapper.draftParameters(evaluation);
      expect(payload['eye_input'], 'left');
      final images = payload['images_input'] as List;
      expect(images, hasLength(3));
      expect(images.first['sha256'], sha256.convert(photo(1)).toString());
      expect(images.last['position'], 3);
      expect(payload.containsKey('professional_id'), isFalse);
      expect(payload.containsKey('results'), isFalse);
      expect(
        images.any((image) => image.containsKey('upload_status')),
        isFalse,
      );
    },
  );

  test(
    'Unknown evaluation states are rejected rather than silently reclassified',
    () {
      final row = storedEvaluation()..['status'] = 'unknown';
      expect(() => EvaluationMapper.fromJson(row), throwsA(isA<AppFailure>()));
    },
  );
}
