import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rd_app/app/dependencies.dart';
import 'package:rd_app/features/admin/data/repositories/in_memory_admin_repository.dart';
import 'package:rd_app/features/admin/domain/entities/admin_account.dart';
import 'package:rd_app/features/auth/data/repositories/preview_auth_repository.dart';
import 'package:rd_app/features/auth/domain/entities/staff_member.dart';
import 'package:rd_app/features/evaluations/data/repositories/in_memory_evaluation_repository.dart';
import 'package:rd_app/features/patients/data/repositories/in_memory_patient_repository.dart';
import 'package:rd_app/features/patients/domain/entities/patient.dart';
import 'package:rd_app/features/patients/presentation/pages/patient_detail_screen.dart';
import 'package:rd_app/features/patients/presentation/pages/patient_form_screen.dart';

import '../../support/fixtures.dart';

class LifecycleAdmin extends InMemoryAdminRepository {
  final InMemoryPatientRepository patients;
  LifecycleAdmin(this.patients)
    : super([
        AdminAccount(
          id: 'admin',
          name: 'Administrador',
          email: 'admin@example.invalid',
          role: AccountRole.admin,
          active: true,
          confirmed: true,
          createdAt: DateTime(2026),
        ),
        AdminAccount(
          id: 'professional',
          name: 'Profesional elegible',
          email: 'professional@example.invalid',
          role: AccountRole.professional,
          active: true,
          confirmed: true,
          createdAt: DateTime(2026),
        ),
        AdminAccount(
          id: 'pending',
          name: 'Pendiente',
          email: 'pending@example.invalid',
          role: AccountRole.professional,
          active: true,
          confirmed: false,
          createdAt: DateTime(2026),
        ),
      ]);
  @override
  Future<void> setPatientActive(String id, bool active, String reason) async {
    final p = (await patients.findById(id))!;
    await patients.update(
      Patient(
        id: p.id,
        dni: p.dni,
        ownerId: p.ownerId,
        ownerName: p.ownerName,
        nombres: p.nombres,
        apellidos: p.apellidos,
        fechaNacimiento: p.fechaNacimiento,
        sexo: p.sexo,
        telefono: p.telefono,
        direccion: p.direccion,
        historiaClinica: p.historiaClinica,
        isActive: active,
        deactivationReason: active ? null : reason,
      ),
    );
  }
}

Future<AppDependencies> dependencies() async {
  final patients = InMemoryPatientRepository();
  await patients.save(
    Patient(
      id: 'patient',
      dni: '12345678',
      ownerId: 'professional',
      nombres: 'Paciente',
      apellidos: 'Prueba',
      fechaNacimiento: DateTime(1980),
      sexo: Sexo.femenino,
    ),
  );
  final d = AppDependencies(
    authRepository: PreviewAuthRepository(),
    patientRepository: patients,
    evaluationRepository: InMemoryEvaluationRepository(),
    imageRepository: TestImageRepository(),
    adminRepository: LifecycleAdmin(patients),
  );
  d.session.auth.personal = const StaffMember(
    id: 'admin',
    usuario: 'admin@example.invalid',
    nombre: 'Administrador',
    role: AccountRole.admin,
  );
  await d.session.patients.load();
  return d;
}

void main() {
  testWidgets('Admin registration requires an eligible professional', (
    tester,
  ) async {
    final d = await dependencies();
    await tester.pumpWidget(harness(d, PatientFormScreen(sesion: d.session)));
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Selecciona un profesional responsable'), findsOneWidget);
    expect(d.session.patients.patients.length, 1);
    await tester.ensureVisible(find.text('Profesional responsable'));
    await tester.tap(find.text('Profesional responsable'));
    await tester.pumpAndSettle();
    expect(find.text('Profesional elegible'), findsOneWidget);
    expect(find.text('Administrador'), findsNothing);
    expect(find.text('Pendiente'), findsNothing);
    await tester.tap(find.text('Profesional elegible'));
    await tester.pumpAndSettle();
    expect(find.text('Profesional elegible'), findsOneWidget);
  });

  testWidgets(
    'Admin deactivates with reason and reactivates without deleting patient',
    (tester) async {
      final d = await dependencies();
      await tester.pumpWidget(
        harness(
          d,
          PatientDetailScreen(patientId: 'patient', session: d.session),
        ),
      );
      expect(find.text('Nueva evaluación'), findsNothing);
      await tester.ensureVisible(find.text('Desactivar paciente'));
      await tester.tap(find.text('Desactivar paciente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desactivar', skipOffstage: false));
      await tester.pumpAndSettle();
      expect(find.text('Indica el motivo'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('patient-deactivation-reason')),
        'Seguimiento finalizado',
      );
      await tester.tap(find.text('Desactivar'));
      await tester.pumpAndSettle();
      expect(d.session.patients.byId('patient')!.isActive, isFalse);
      expect(d.session.patients.search(''), isEmpty);
      expect(d.session.patients.search('', inactive: true).length, 1);
      expect(find.text('Seguimiento finalizado'), findsOneWidget);
      await tester.ensureVisible(find.text('Reactivar paciente'));
      await tester.tap(find.text('Reactivar paciente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reactivar'));
      await tester.pumpAndSettle();
      expect(d.session.patients.byId('patient')!.isActive, isTrue);
      expect(d.session.patients.patients.length, 1);
    },
  );

  testWidgets('Inactive patient has no clinical actions for a professional', (
    tester,
  ) async {
    final d = await dependencies();
    await d.session.admin.setPatientActive('patient', false, 'Archivado');
    await d.session.patients.load();
    d.session.auth.personal = const StaffMember(
      id: 'professional',
      usuario: 'professional@example.invalid',
      nombre: 'Profesional',
    );
    await tester.pumpWidget(
      harness(d, PatientDetailScreen(patientId: 'patient', session: d.session)),
    );
    expect(find.text('Desactivado'), findsOneWidget);
    expect(find.text('Editar paciente'), findsNothing);
    expect(find.text('Nueva evaluación'), findsNothing);
    expect(find.byKey(const Key('patient-activity')), findsNothing);
  });
}
