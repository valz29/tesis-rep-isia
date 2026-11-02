import 'package:flutter/foundation.dart';

import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/patients/presentation/controllers/patients_controller.dart';
import '../features/evaluations/presentation/controllers/evaluations_controller.dart';
import '../features/evaluations/presentation/controllers/capture_controller.dart';
import '../features/evaluations/domain/usecases/select_evaluation_image.dart';

/// Presentation composition for a signed-in session, not a storage service.
/// Each feature owns its state. No widgets instantiate concrete repositories.
class SessionController {
  final AuthController auth;
  final PatientsController patients;
  final EvaluationsController evaluations;
  final SelectEvaluationImage _selectImage;
  SessionController(
    this.auth,
    this.patients,
    this.evaluations,
    this._selectImage,
  );
  Listenable get changes => Listenable.merge([patients, evaluations]);
  CaptureController createCaptureController() =>
      CaptureController(_selectImage);
  Future<void> logout() async {
    await evaluations.clear();
    await patients.clear();
    await auth.logout();
  }

  void dispose() {
    auth.dispose();
    patients.dispose();
    evaluations.dispose();
  }
}
