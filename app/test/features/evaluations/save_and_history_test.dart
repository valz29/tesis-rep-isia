import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:rd_app/core/errors/app_failure.dart';
import 'package:rd_app/features/evaluations/data/repositories/in_memory_evaluation_repository.dart';
import 'package:rd_app/features/evaluations/domain/entities/evaluation.dart';
import 'package:rd_app/features/evaluations/domain/entities/evaluation_draft.dart';
import 'package:rd_app/features/evaluations/domain/entities/evaluation_image.dart';
import 'package:rd_app/features/evaluations/domain/entities/evaluation_image_metadata.dart';
import 'package:rd_app/features/evaluations/presentation/pages/history_screen.dart';
import 'package:rd_app/features/evaluations/presentation/pages/result_screen.dart';
import 'package:rd_app/features/home/presentation/pages/home_screen.dart';

import '../../support/fixtures.dart';

Evaluation evaluation({bool stored = false, bool draft = false}) => Evaluation(
  id: '30000000-0000-0000-0000-000000000001',
  patientId: patient.id,
  professionalId: patient.ownerId!,
  ojo: OjoEvaluado.derecho,
  fecha: DateTime(2026, 11, 12),
  status: draft ? EvaluationStatus.draft : EvaluationStatus.pendingAnalysis,
  imagenes: stored
      ? []
      : [for (var n = 1; n <= 3; n++) EvaluationImage(photo(n))],
  imageMetadata: [
    for (var n = 1; n <= 3; n++)
      EvaluationImageMetadata(
        position: n,
        sha256: sha256.convert(photo(n)).toString(),
        contentType: 'image/png',
        byteSize: photo(n).length,
        uploaded: stored,
      ),
  ],
);

class DelayedSaveRepository extends InMemoryEvaluationRepository {
  final finish = Completer<void>();
  int saves = 0;
  int lists = 0;
  bool fail = false;

  @override
  Future<Evaluation> save(Evaluation evaluation) async {
    saves++;
    await finish.future;
    if (fail) throw const AppFailure('No se pudieron subir las fotos');
    return super.save(evaluation);
  }

  @override
  Future<List<Evaluation>> list() async {
    lists++;
    throw const AppFailure(
      'No debe recargarse todo el historial después de guardar',
    );
  }
}

class ColdHistoryRepository extends InMemoryEvaluationRepository {
  final Evaluation record;
  int thumbnails = 0;
  int details = 0;
  bool failPreview = false;
  ColdHistoryRepository(this.record);

  @override
  Future<List<Evaluation>> list() async => [record];

  @override
  Future<EvaluationImage?> loadThumbnail(Evaluation evaluation) async {
    thumbnails++;
    if (failPreview) throw const AppFailure('Sin conexión');
    return EvaluationImage(photo(1));
  }

  @override
  Future<List<EvaluationImage>> loadImages(String id) async {
    details++;
    return [for (var n = 1; n <= 3; n++) EvaluationImage(photo(n))];
  }
}

void main() {
  testWidgets(
    'Save displays progress, prevents duplicate requests and returns home only after success',
    (tester) async {
      final repository = DelayedSaveRepository();
      final dependencies = await createDependencies(
        seedPatient: true,
        evaluations: repository,
      );
      addTearDown(dependencies.dispose);
      await tester.pumpWidget(
        harness(
          dependencies,
          ResultScreen(evaluacion: evaluation(), sesion: dependencies.session),
        ),
      );
      final save = find.widgetWithText(FilledButton, 'Guardar');
      await tester.ensureVisible(save);
      final initialQueries = repository.lists;
      await tester.tap(save);
      await tester.pump();
      expect(find.text('Guardando…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Guardando…'),
            )
            .onPressed,
        isNull,
      );
      expect(repository.saves, 1);

      repository.finish.complete();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ResultScreen), findsNothing);
      expect(repository.lists, initialQueries);
      expect(dependencies.session.evaluations.evaluations, hasLength(1));
    },
  );

  testWidgets(
    'Failed upload stays on result and enables retry without announcing success',
    (tester) async {
      final repository = DelayedSaveRepository()..fail = true;
      final dependencies = await createDependencies(
        seedPatient: true,
        evaluations: repository,
      );
      addTearDown(dependencies.dispose);
      await tester.pumpWidget(
        harness(
          dependencies,
          ResultScreen(evaluacion: evaluation(), sesion: dependencies.session),
        ),
      );
      final save = find.widgetWithText(FilledButton, 'Guardar');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      repository.finish.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ResultScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('No se pudieron subir las fotos'), findsOneWidget);
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      expect(dependencies.session.evaluations.evaluations, isEmpty);
    },
  );

  testWidgets(
    'Cold history loads first preview without opening evaluation or downloading all images',
    (tester) async {
      final repository = ColdHistoryRepository(evaluation(stored: true));
      final dependencies = await createDependencies(
        seedPatient: true,
        evaluations: repository,
      );
      addTearDown(dependencies.dispose);
      await dependencies.session.evaluations.load();
      await tester.pumpWidget(
        harness(dependencies, HistoryScreen(sesion: dependencies.session)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(repository.thumbnails, 1);
      expect(repository.details, 0);
      expect(find.byType(ResultScreen), findsNothing);
    },
  );

  testWidgets(
    'Thumbnail failure offers retry and does not block opening history',
    (tester) async {
      final repository = ColdHistoryRepository(evaluation(stored: true))
        ..failPreview = true;
      final dependencies = await createDependencies(
        seedPatient: true,
        evaluations: repository,
      );
      addTearDown(dependencies.dispose);
      await dependencies.session.evaluations.load();
      await tester.pumpWidget(
        harness(dependencies, HistoryScreen(sesion: dependencies.session)),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Reintentar miniatura'), findsOneWidget);
      repository.failPreview = false;
      await tester.tap(find.byTooltip('Reintentar miniatura'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(repository.thumbnails, 2);
    },
  );

  test('A draft in history is not treated as a confirmed save', () async {
    final repository = ColdHistoryRepository(
      evaluation(stored: true, draft: true),
    );
    final dependencies = await createDependencies(
      seedPatient: true,
      evaluations: repository,
    );
    addTearDown(dependencies.dispose);
    await dependencies.session.evaluations.load();
    expect(
      dependencies.session.evaluations.isSaved(repository.record.id),
      isFalse,
    );
  });

  test(
    'A save finishing after local session clear cannot restore old records',
    () async {
      final repository = DelayedSaveRepository();
      final dependencies = await createDependencies(
        seedPatient: true,
        evaluations: repository,
      );
      addTearDown(dependencies.dispose);
      final controller = dependencies.session.evaluations;
      final pending = controller.save(evaluation());
      await Future<void>.delayed(Duration.zero);
      await controller.clear();
      repository.finish.complete();
      expect(await pending, isFalse);
      expect(controller.evaluations, isEmpty);
      expect(controller.busy, isFalse);
    },
  );
}
