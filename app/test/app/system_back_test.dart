import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rd_app/app/app.dart';
import 'package:rd_app/features/auth/presentation/login_screen.dart';
import 'package:rd_app/features/auth/presentation/recovery_screen.dart';
import 'package:rd_app/features/auth/presentation/welcome_screen.dart';
import 'package:rd_app/features/home/presentation/home_screen.dart';
import 'package:rd_app/features/patients/presentation/patient_selection_screen.dart';

import '../support/fixtures.dart';

void main() {
  testWidgets(
    'System back traverses the session navigator one screen at a time',
    (tester) async {
      final dependencies = memoryDependencies();
      addTearDown(dependencies.dispose);
      await tester.pumpWidget(RetinazoApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();
      expect(find.byType(RecoveryScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(RecoveryScreen), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'demo@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'demo12345');
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu-0')));
      await tester.pumpAndSettle();
      expect(find.byType(PatientSelectionScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(PatientSelectionScreen), findsNothing);
      // Back closes the drawer before it can leave the home screen.
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester.state<ScaffoldState>(find.byType(Scaffold).last).isDrawerOpen,
        isFalse,
      );
    },
  );
}
