import '../../../../core/errors/app_failure.dart';
import '../../../patients/domain/repositories/patient_repository.dart';
import '../entities/evaluation.dart';
import '../repositories/evaluation_repository.dart';

class SaveEvaluation {
  final EvaluationRepository _evaluations;
  final PatientRepository _patients;
  const SaveEvaluation(this._evaluations, this._patients);
  Future<void> call(Evaluation evaluation) async {
    if (await _patients.findById(evaluation.patientId) == null) {
      throw const AppFailure(
        'El paciente de esta evaluación no está disponible',
      );
    }
    await _evaluations.save(evaluation);
  }
}
