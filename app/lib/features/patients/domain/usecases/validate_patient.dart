import '../../../../core/errors/app_failure.dart';
import '../entities/patient.dart';

void validatePatient(Patient patient, DateTime now) {
  if (patient.id.isEmpty ||
      !RegExp(r'^\d{8}$').hasMatch(patient.dni) ||
      patient.nombres.trim().isEmpty ||
      patient.apellidos.trim().isEmpty ||
      patient.fechaNacimiento.isAfter(now) ||
      (patient.telefono != null &&
          !RegExp(r'^\d{9}$').hasMatch(patient.telefono!))) {
    throw const AppFailure('Revisa los datos del paciente');
  }
}
