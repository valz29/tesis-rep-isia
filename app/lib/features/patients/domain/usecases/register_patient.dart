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
    final existing = await _repository.findByDni(
      patient.dni,
      ownerId: patient.ownerId,
    );
    if (existing != null) {
      throw AppFailure(
        existing.isActive ? 'Este DNI ya está registrado' : 'El DNI ya tiene un expediente desactivado; requiere reactivación',
      );
    }
    await _repository.save(patient);
  }
}
