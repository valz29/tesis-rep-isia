import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rd_app/app/dependencies.dart';
import 'package:rd_app/features/admin/data/repositories/in_memory_admin_repository.dart';
import 'package:rd_app/features/admin/domain/entities/admin_account.dart';
import 'package:rd_app/features/admin/presentation/pages/admin_users_screen.dart';
import 'package:rd_app/features/auth/data/repositories/preview_auth_repository.dart';
import 'package:rd_app/features/auth/domain/entities/staff_member.dart';
import 'package:rd_app/features/patients/data/repositories/in_memory_patient_repository.dart';
import 'package:rd_app/features/evaluations/data/repositories/in_memory_evaluation_repository.dart';
import 'package:rd_app/features/home/presentation/pages/home_screen.dart';

import '../../support/fixtures.dart';

const admin = StaffMember(
  id: 'admin',
  usuario: 'admin@example.invalid',
  nombre: 'Admin',
  role: AccountRole.admin,
);

class AdminAuth extends PreviewAuthRepository {
  @override
  Future<StaffMember?> currentStaff() async => admin;
}

void main() {
  testWidgets(
    'Administrator has exclusive user management and can edit an account',
    (tester) async {
      final repo = InMemoryAdminRepository([
        AdminAccount(
          id: 'professional',
          name: 'Profesional prueba',
          email: 'professional@example.invalid',
          role: AccountRole.professional,
          active: true,
          confirmed: false,
          createdAt: DateTime(2026),
        ),
      ]);
      final d = AppDependencies(
        authRepository: AdminAuth(),
        patientRepository: InMemoryPatientRepository(),
        evaluationRepository: InMemoryEvaluationRepository(),
        imageRepository: TestImageRepository(),
        adminRepository: repo,
      );
      d.session.auth.personal = admin;
      await d.session.admin.load();
      await tester.pumpWidget(harness(d, HomeScreen(sesion: d.session)));
      expect(find.text('Panel de administración'), findsOneWidget);
      expect(find.text('Usuarios'), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu-0')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Correo pendiente'), findsOneWidget);
      await tester.tap(find.text('Profesional prueba'));
      await tester.pumpAndSettle();
      expect(find.text('Pendiente de confirmar su correo'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Nombre corregido',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(repo.accounts.single.name, 'Nombre corregido');
      expect(find.text('Nombre corregido'), findsOneWidget);
      expect(d.session.auth.personal?.isAdmin, isTrue);
    },
  );
  testWidgets('Professional cannot open the administrator user screen', (
    tester,
  ) async {
    final d = await createDependencies();
    await tester.pumpWidget(harness(d, AdminUsersScreen(session: d.session)));
    await tester.pumpAndSettle();
    expect(find.text('Acceso exclusivo de administración'), findsOneWidget);
    expect(find.text('Gestión de usuarios'), findsNothing);
  });
}
