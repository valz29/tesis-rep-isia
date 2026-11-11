import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:rd_app/core/errors/app_failure.dart';
import 'package:rd_app/features/evaluations/data/repositories/in_memory_evaluation_repository.dart';
import 'package:rd_app/features/evaluations/domain/entities/detection_result.dart';
import 'package:rd_app/features/evaluations/domain/entities/evaluation.dart';
import 'package:rd_app/features/evaluations/domain/entities/evaluation_draft.dart';
import 'package:rd_app/features/evaluations/domain/entities/evaluation_image.dart';
import 'package:rd_app/features/evaluations/domain/usecases/create_evaluation.dart';
import 'package:rd_app/features/evaluations/domain/usecases/save_evaluation.dart';
import 'package:rd_app/features/patients/data/repositories/in_memory_patient_repository.dart';

import '../../support/fixtures.dart';

List<EvaluationImage> images() => [
  for (var n = 1; n <= 3; n++) EvaluationImage(photo(n)),
];
Evaluation evaluation({
  List<EvaluationImage>? photos,
  EvaluationStatus status = EvaluationStatus.pendingAnalysis,
  DetectionResult? result,
}) => Evaluation(
  id: 'evaluation-1',
  patientId: patient.id,
  ojo: OjoEvaluado.derecho,
  imagenes: photos ?? images(),
  fecha: DateTime(2026, 11, 2),
  professionalId: 'staff-1',
  status: status,
  result: result,
);

void main() {
  test('Incomplete or repeated image sets cannot become evaluations', () {
    for (final count in [0, 1, 2, 4]) {
      expect(
        () => evaluation(
          photos: [for (var n = 1; n <= count; n++) EvaluationImage(photo(n))],
        ),
        throwsA(isA<AppFailure>()),
      );
    }
    expect(
      () => evaluation(
        photos: [
          EvaluationImage(photo(1)),
          EvaluationImage(photo(2)),
          EvaluationImage(photo(1)),
        ],
      ),
      throwsA(isA<AppFailure>()),
    );
  });

  test('Accepted images cannot be changed through caller byte buffers', () {
    final input = Uint8List.fromList([1, 2, 3]);
    final image = EvaluationImage(input);
    input[0] = 9;
    final output = image.bytes;
    expect(() => output[1] = 9, throwsUnsupportedError);
    expect(image.bytes, [1, 2, 3]);
    final photos = images();
    final record = evaluation(photos: photos);
    photos.clear();
    expect(record.imagenes.length, 3);
    expect(() => record.imagenes.clear(), throwsUnsupportedError);
  });

  test('Pending and ungradable are distinct from a completed grade zero', () {
    expect(evaluation().result, isNull);
    final ungradable = evaluation(status: EvaluationStatus.notGradable);
    expect(ungradable.result, isNull);
    final gradeZero = DetectionResult(gradoICDR: 0, modelVersion: 'test-only');
    final completed = evaluation(
      status: EvaluationStatus.completed,
      result: gradeZero,
    );
    expect(completed.result!.gradoICDR, 0);
    expect(
      () => evaluation(status: EvaluationStatus.completed),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => evaluation(status: EvaluationStatus.notGradable, result: gradeZero),
      throwsA(isA<AppFailure>()),
    );
    expect(() => evaluation(result: gradeZero), throwsA(isA<AppFailure>()));
  });

  test('Invalid model responses are rejected before displaying a grade', () {
    for (final grade in [-1, 5]) {
      expect(
        () => DetectionResult(gradoICDR: grade, modelVersion: 'test-only'),
        throwsA(isA<AppFailure>()),
      );
    }
    for (final confidence in [-0.1, 1.1, double.nan, double.infinity]) {
      expect(
        () => DetectionResult(
          gradoICDR: 2,
          modelVersion: 'test-only',
          confianza: confidence,
        ),
        throwsA(isA<AppFailure>()),
      );
    }
    expect(
      () => DetectionResult(gradoICDR: 2, modelVersion: ''),
      throwsA(isA<AppFailure>()),
    );
  });

  test('Both eyes reference one patient; preparing does not save; saving is idempotent', () async {
    final patients = InMemoryPatientRepository();
    final records = InMemoryEvaluationRepository();
    var next = 0;
    final time = DateTime(2026, 11, 2, 9);
    final create = CreateEvaluation(
      patients,
      () => 'eval-${++next}',
      () => time,
    );
    final save = SaveEvaluation(records, patients);
    final rightDraft = EvaluationDraft(
      patientId: patient.id,
      ojo: OjoEvaluado.derecho,
    );
    await expectLater(
      create(rightDraft, images(), 'staff-1'),
      throwsA(isA<AppFailure>()),
    );
    await patients.save(patient);
    final right = await create(rightDraft, images(), patient.ownerId!);
    final left = await create(
      EvaluationDraft(
        patientId: patient.id,
        ojo: OjoEvaluado.izquierdo,
        observaciones: 'Nueva visita',
      ),
      images(),
      patient.ownerId!,
    );
    expect(await records.list(), isEmpty);
    await save(right);
    await save(right);
    await save(left);
    expect((await records.list()).length, 2);
    expect((await patients.list()).length, 1);
    expect(right.patientId, left.patientId);
    expect(right.id, isNot(left.id));
    expect(right.fecha, time);
    expect(right.observaciones, isNull);
    expect(left.observaciones, 'Nueva visita');
    await patients.clear();
    await expectLater(save(left), throwsA(isA<AppFailure>()));
  });

  test(
    'Logging out clears temporary records before the next professional',
    () async {
      final dependencies = await createDependencies(seedPatient: true);
      addTearDown(dependencies.dispose);
      final session = dependencies.session;
      final record = await session.evaluations.prepare(
        EvaluationDraft(patientId: patient.id, ojo: OjoEvaluado.derecho),
        images(),
        session.auth.personal!.id,
      );
      expect(await session.evaluations.save(record!), isTrue);
      await session.logout();
      await session.auth.login('other@example.com', 'test');
      await session.patients.load();
      expect(session.patients.patients, isEmpty);
      expect(session.evaluations.evaluations, isEmpty);
      expect(session.auth.personal!.usuario, 'other@example.com');
    },
  );
}
