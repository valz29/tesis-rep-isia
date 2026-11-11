import '../../../../core/errors/app_failure.dart';
import '../../../patients/domain/repositories/patient_repository.dart';
import '../entities/evaluation.dart';
import '../repositories/evaluation_repository.dart';

class SaveEvaluation {
  final EvaluationRepository _evaluations;
  final PatientRepository _patients;
  const SaveEvaluation(this._evaluations, this._patients);
  Future<void> call(Evaluation evaluation) async {
    final patient = await _patients.findById(evaluation.patientId);
    if (patient == null) {
      throw const AppFailure(
        'El paciente de esta evaluación no está disponible',
      );
    }
    if (!patient.isActive) {
      throw const AppFailure(
        'El paciente está desactivado. Su historial se conserva',
      );
    }
    if (patient.ownerId != null &&
        patient.ownerId != evaluation.professionalId) {
      throw const AppFailure(
        'Solo el profesional responsable puede guardar la evaluación',
      );
    }
    await _evaluations.save(evaluation);
  }
}
