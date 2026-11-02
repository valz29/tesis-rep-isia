import 'package:flutter_test/flutter_test.dart';
import 'package:rd_app/core/errors/app_failure.dart';
import 'package:rd_app/features/patients/data/repositories/in_memory_patient_repository.dart';
import 'package:rd_app/features/patients/domain/entities/patient.dart';
import 'package:rd_app/features/patients/domain/usecases/register_patient.dart';

Patient patient({
  String id = 'patient-1',
  String dni = '12345678',
  DateTime? birth,
}) => Patient(
  id: id,
  dni: dni,
  nombres: 'Nombre',
  apellidos: 'Apellido',
  fechaNacimiento: birth ?? DateTime(1980, 6, 15),
  sexo: Sexo.femenino,
);

void main() {
  test('Invalid or duplicate DNI never creates another patient', () async {
    final repository = InMemoryPatientRepository();
    final register = RegisterPatient(repository, () => DateTime(2026, 11, 2));
    await expectLater(
      register(patient(dni: '123')),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      register(patient(birth: DateTime(2027))),
      throwsA(isA<AppFailure>()),
    );
    expect(await repository.list(), isEmpty);
    await register(patient());
    await expectLater(
      register(patient(id: 'patient-2')),
      throwsA(isA<AppFailure>()),
    );
    // Storage also enforces uniqueness when a caller bypasses the use case.
    await expectLater(
      repository.save(patient(id: 'patient-3')),
      throwsA(isA<AppFailure>()),
    );
    expect((await repository.list()).length, 1);
    expect((await repository.findByDni('12345678'))!.id, 'patient-1');
  });
}
