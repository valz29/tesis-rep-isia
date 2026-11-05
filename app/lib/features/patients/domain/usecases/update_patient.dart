import '../../../../core/errors/app_failure.dart';
import '../entities/patient.dart';
import '../repositories/patient_repository.dart';
import 'validate_patient.dart';

class UpdatePatient {
  final PatientRepository _repository;
  final DateTime Function() _now;
  const UpdatePatient(this._repository, this._now);
  Future<void> call(Patient patient) async {
    validatePatient(patient, _now());
    if (await _repository.findById(patient.id) == null) {
      throw const AppFailure('El paciente ya no está disponible');
    }
    final existing = await _repository.findByDni(
      patient.dni,
      ownerId: patient.ownerId,
    );
    if (existing != null && existing.id != patient.id) {
      throw const AppFailure('Este DNI ya está registrado');
    }
    await _repository.update(patient);
  }
}
