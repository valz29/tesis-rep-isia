import '../../../../core/errors/app_failure.dart';
import '../entities/patient.dart';
import '../repositories/patient_repository.dart';

class RegisterPatient {
  final PatientRepository _repository;
  final DateTime Function() _now;
  const RegisterPatient(this._repository, this._now);
  Future<void> call(Patient patient) async {
    if (patient.id.isEmpty ||
        !RegExp(r'^\d{8}$').hasMatch(patient.dni) ||
        patient.nombres.trim().isEmpty ||
        patient.apellidos.trim().isEmpty ||
        patient.fechaNacimiento.isAfter(_now()) ||
        (patient.telefono != null &&
            !RegExp(r'^\d{9}$').hasMatch(patient.telefono!))) {
      throw const AppFailure('Revisa los datos del paciente');
    }
    if (await _repository.findByDni(patient.dni) != null) {
      throw const AppFailure('Este DNI ya está registrado en la sesión');
    }
    await _repository.save(patient);
  }
}
