import '../../../../core/errors/app_failure.dart';
import '../../../patients/domain/repositories/patient_repository.dart';
import '../entities/evaluation.dart';
import '../entities/evaluation_draft.dart';
import '../entities/evaluation_image.dart';

class CreateEvaluation {
  final PatientRepository _patients;
  final String Function() _newId;
  final DateTime Function() _now;
  const CreateEvaluation(this._patients, this._newId, this._now);
  Future<Evaluation> call(
    EvaluationDraft draft,
    List<EvaluationImage> images,
    String professionalId,
  ) async {
    if (await _patients.findById(draft.patientId) == null) {
      throw const AppFailure('Selecciona un paciente registrado');
    }
    return Evaluation(
      id: _newId(),
      patientId: draft.patientId,
      ojo: draft.ojo,
      observaciones: draft.observaciones,
      imagenes: images,
      fecha: _now(),
      professionalId: professionalId,
    );
  }
}
