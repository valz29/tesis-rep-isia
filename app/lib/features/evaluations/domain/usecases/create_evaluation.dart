import '../../../../core/errors/app_failure.dart';
import '../../../patients/domain/repositories/patient_repository.dart';
import '../entities/evaluation.dart';
import '../entities/evaluation_draft.dart';
import '../entities/evaluation_image.dart';

class CreateEvaluation {
  final PatientRepository _patients;
  final String Function() _newId;
  final DateTime Function() _now;
  final EvaluationStatus initialStatus;
  const CreateEvaluation(
    this._patients,
    this._newId,
    this._now, {
    this.initialStatus = EvaluationStatus.pendingAnalysis,
  });
  Future<Evaluation> call(
    EvaluationDraft draft,
    List<EvaluationImage> images,
    String professionalId,
  ) async {
    final patient = await _patients.findById(draft.patientId);
    if (patient == null) {
      throw const AppFailure('Selecciona un paciente registrado');
    }
    if (!patient.isActive) {
      throw const AppFailure(
        'El paciente está desactivado. Su historial se conserva',
      );
    }
    if (patient.ownerId != null && patient.ownerId != professionalId) {
      throw const AppFailure(
        'Solo el profesional responsable puede evaluar al paciente',
      );
    }
    if (images.length != 3) {
      throw const AppFailure('Selecciona tres imágenes diferentes');
    }
    return Evaluation(
      id: _newId(),
      status: initialStatus,
      patientId: draft.patientId,
      ojo: draft.ojo,
      observaciones: draft.observaciones,
      imagenes: images,
      fecha: _now(),
      professionalId: professionalId,
    );
  }
}
