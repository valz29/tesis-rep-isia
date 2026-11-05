import '../../../../core/errors/app_failure.dart';
import '../entities/patient.dart';
import '../repositories/patient_repository.dart';
import 'validate_patient.dart';

class RegisterPatient {
  final PatientRepository _repository;
  final DateTime Function() _now;
  const RegisterPatient(this._repository, this._now);
  Future<void> call(Patient patient) async {
    validatePatient(patient, _now());
    if (await _repository.findByDni(patient.dni, ownerId: patient.ownerId) !=
        null) {
      throw const AppFailure('Este DNI ya está registrado');
    }
    await _repository.save(patient);
  }
}
