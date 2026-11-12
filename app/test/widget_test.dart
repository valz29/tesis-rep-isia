import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rd_app/app/app.dart';
import 'package:rd_app/features/auth/domain/entities/staff_member.dart';
import 'package:rd_app/features/evaluations/domain/entities/evaluation_draft.dart';
import 'package:rd_app/features/evaluations/domain/entities/evaluation_image.dart';
import 'package:rd_app/features/evaluations/presentation/pages/capture_screen.dart';
import 'package:rd_app/features/evaluations/presentation/pages/eye_selection_screen.dart';
import 'package:rd_app/features/evaluations/presentation/pages/history_screen.dart';
import 'package:rd_app/features/evaluations/presentation/pages/result_screen.dart';
import 'package:rd_app/features/evaluations/presentation/pages/review_screen.dart';
import 'package:rd_app/features/evaluations/presentation/pages/single_image_preview_screen.dart';
import 'package:rd_app/features/home/presentation/pages/home_screen.dart';
import 'package:rd_app/features/patients/domain/entities/patient.dart';
import 'package:rd_app/features/patients/presentation/pages/patient_selection_screen.dart';

import 'support/fixtures.dart';

Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scroll = find.byType(Scrollable).first;
    await tester.drag(scroll, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(finder, 250, scrollable: scroll);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Welcome, registration validation, login and menu navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const RetinazoApp());
    await tester.pumpAndSettle();
    expect(find.text('Retinazo'), findsOneWidget);
    await tapVisible(tester, find.text('Registrarse'));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Personal de prueba',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'demo@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'demo12345');
    await tester.enterText(find.byType(TextFormField).at(3), 'otro');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Registrarse'));
    expect(find.text('Las contraseñas deben coincidir'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(3), 'demo12345');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Registrarse'));
    expect(
      find.text('Confirma tu correo para activar tu cuenta.'),
      findsOneWidget,
    );
    expect(find.byType(HomeScreen), findsNothing);
    await tapVisible(
      tester,
      find.text('Ya confirmé mi correo · Iniciar sesión'),
    );
    expect(find.text('demo@example.com'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Iniciar sesión'),
    );
    expect(find.text('Ingresa un correo electrónico válido'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'demo@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'demo12345');
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Iniciar sesión'),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('menu-0')));
    expect(find.text('Todavía no hay pacientes'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('menu-3')));
    expect(find.text('Estadísticas'), findsOneWidget);
    expect(find.text('Evaluaciones guardadas'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Cerrar sesión'));
    await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Retinazo'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Patient search reuses identity and selects eye before capture', (
    tester,
  ) async {
    final dependencies = await createDependencies(seedPatient: true);
    final session = dependencies.session;
    await tester.pumpWidget(
      harness(
        dependencies,
        PatientSelectionScreen(sesion: session, paraEvaluar: true),
      ),
    );
    await tester.enterText(find.byType(TextField), 'no existe');
    await tester.pumpAndSettle();
    expect(find.text('Sin coincidencias'), findsOneWidget);
    await tester.enterText(find.byType(TextField), patient.dni);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text(patient.nombreCompleto));
    expect(find.byType(EyeSelectionScreen), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continuar'))
          .onPressed,
      isNull,
    );
    await tapVisible(tester, find.text('Ojo izquierdo'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
    final capture = tester.widget<CaptureScreen>(find.byType(CaptureScreen));
    expect(capture.draft.ojo, OjoEvaluado.izquierdo);
    expect(session.patients.patients.length, 1);
  });

  testWidgets('Registering a patient only updates the current session', (
    tester,
  ) async {
    final dependencies = await createDependencies();
    final session = dependencies.session;
    await tester.pumpWidget(
      harness(dependencies, PatientSelectionScreen(sesion: session)),
    );
    await tapVisible(tester, find.byTooltip('Registrar paciente'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));
    expect(find.text('Ingresa los nombres'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('patient-name')), 'Nombre');
    await tester.enterText(
      find.byKey(const Key('patient-surname')),
      'Apellido',
    );
    await tester.enterText(find.byKey(const Key('patient-dni')), '87654321');
    await tapVisible(
      tester,
      find.widgetWithText(TextFormField, 'Fecha de nacimiento'),
    );
    await tapVisible(tester, find.text('OK'));
    await tapVisible(tester, find.byType(DropdownButtonFormField<Sexo>));
    await tapVisible(tester, find.text('Femenino').last);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Dirección (opcional)'),
      'Dirección de prueba',
    );
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));
    expect(session.patients.patients.length, 1);
    expect(session.patients.patients.single.direccion, 'Dirección de prueba');
    expect(find.byType(PatientSelectionScreen), findsOneWidget);
    expect(find.byType(CaptureScreen), findsNothing);
    final fresh = await createDependencies();
    expect(fresh.session.patients.patients, isEmpty);
    fresh.dispose();
  });

  testWidgets('Patient edits preserve identity and update the details page', (
    tester,
  ) async {
    final dependencies = await createDependencies(seedPatient: true);
    await tester.pumpWidget(
      harness(
        dependencies,
        PatientSelectionScreen(sesion: dependencies.session),
      ),
    );
    await tapVisible(tester, find.text(patient.nombreCompleto));
    await tapVisible(tester, find.text('Editar paciente'));
    await tester.enterText(
      find.byKey(const Key('patient-name')),
      'Nombre actualizado',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));
    expect(dependencies.session.patients.patients.single.id, patient.id);
    expect(
      dependencies.session.patients.patients.single.nombres,
      'Nombre actualizado',
    );
    expect(
      find.text('Nombre actualizado ${patient.apellidos}'),
      findsOneWidget,
    );
  });

  testWidgets('Admin manages patients without authoring evaluations', (
    tester,
  ) async {
    final dependencies = await createDependencies(seedPatient: true);
    dependencies.session.auth.personal = const StaffMember(
      id: 'admin-1',
      usuario: 'admin@example.invalid',
      nombre: 'Admin',
      role: AccountRole.admin,
    );
    await tester.pumpWidget(
      harness(
        dependencies,
        PatientSelectionScreen(sesion: dependencies.session),
      ),
    );
    expect(find.byTooltip('Registrar paciente'), findsOneWidget);
    await tapVisible(tester, find.text(patient.nombreCompleto));
    expect(find.text('Editar paciente'), findsOneWidget);
    expect(find.text('Nueva evaluación'), findsNothing);
    expect(find.text('Cambiar responsable'), findsOneWidget);
    expect(find.text('Profesional responsable'), findsOneWidget);
    expect(find.text('Desactivar paciente'), findsOneWidget);
  });

  testWidgets('Menu supports a narrow screen and enlarged text', (
    tester,
  ) async {
    final dependencies = await createDependencies();
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      harness(
        dependencies,
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: HomeScreen(sesion: dependencies.session),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.byKey(const Key('menu-1')));
    expect(find.text('Seleccionar paciente'), findsOneWidget);
  });

  testWidgets(
    'Three-image preview, confirmation, pending result and explicit save',
    (tester) async {
      final picker = TestImageRepository();
      final dependencies = await createDependencies(
        seedPatient: true,
        images: picker,
      );
      final session = dependencies.session;
      await tester.pumpWidget(
        harness(
          dependencies,
          CaptureScreen(
            paciente: patient,
            sesion: session,
            draft: const EvaluationDraft(
              patientId: 'patient-1',
              ojo: OjoEvaluado.derecho,
            ),
          ),
        ),
      );

      Future<void> pick(
        int slot,
        EvaluationImage? file, {
        bool accept = true,
      }) async {
        picker.next = file;
        await tapVisible(tester, find.byKey(Key('image-slot-$slot')));
        await tester.runAsync(() async {
          await tester.tap(find.text('Elegir de la galería'));
          await tester.pump(const Duration(milliseconds: 400));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pumpAndSettle();
        if (find.byType(SingleImagePreviewScreen).evaluate().isNotEmpty) {
          await tapVisible(
            tester,
            find.text(accept ? 'Usar imagen' : 'Volver a tomar'),
          );
        }
      }

      FilledButton review() =>
          tester.widget<FilledButton>(find.byKey(const Key('review-images')));
      expect(review().onPressed, isNull);
      await pick(0, null);
      expect(find.text('0 de 3 imágenes seleccionadas'), findsOneWidget);
      await pick(0, EvaluationImage(photo(1)), accept: false);
      expect(find.text('0 de 3 imágenes seleccionadas'), findsOneWidget);
      await pick(0, EvaluationImage(photo(1)));
      await pick(1, EvaluationImage(photo(1)));
      expect(find.text('1 de 3 imágenes seleccionadas'), findsOneWidget);
      await pick(1, EvaluationImage(photo(2)));
      await pick(2, EvaluationImage(photo(3)));
      expect(review().onPressed, isNotNull);
      await tapVisible(tester, find.text('Revisar las tres imágenes'));
      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('show-evaluation')))
            .onPressed,
        isNull,
      );
      await tapVisible(tester, find.text('Cambiar imágenes'));
      await tapVisible(tester, find.byTooltip('Quitar imagen 3'));
      expect(review().onPressed, isNull);
      await pick(2, EvaluationImage(photo(4)));
      await tapVisible(tester, find.text('Revisar las tres imágenes'));
      await tapVisible(tester, find.byType(CheckboxListTile));
      await tapVisible(tester, find.byKey(const Key('show-evaluation')));
      expect(find.byType(ResultScreen), findsOneWidget);
      expect(find.text('Pendiente de análisis'), findsOneWidget);
      expect(find.text('87%'), findsNothing);
      expect(find.text('Grado 2'), findsNothing);
      expect(find.textContaining('demostración'), findsNothing);
      expect(session.evaluations.evaluations, isEmpty);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));
      expect(session.evaluations.evaluations.length, 1);
      expect(session.evaluations.evaluations.single.imagenes.length, 3);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ResultScreen), findsNothing);
      expect(
        find.text('Evaluación e imágenes guardadas correctamente.'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        harness(
          dependencies,
          HistoryScreen(sesion: session),
          key: const ValueKey('history-after-save'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(patient.nombreCompleto), findsOneWidget);
      await tapVisible(tester, find.text(patient.nombreCompleto));
      expect(find.byType(ResultScreen), findsOneWidget);
      expect(session.evaluations.evaluations.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
