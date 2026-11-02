import 'dart:math';

import 'package:image_picker/image_picker.dart';

import '../features/auth/data/repositories/preview_auth_repository.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/usecases/sign_in.dart';
import '../features/auth/domain/usecases/sign_out.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/patients/data/repositories/in_memory_patient_repository.dart';
import '../features/patients/domain/repositories/patient_repository.dart';
import '../features/patients/domain/usecases/register_patient.dart';
import '../features/patients/presentation/controllers/patients_controller.dart';
import '../features/evaluations/data/repositories/in_memory_evaluation_repository.dart';
import '../features/evaluations/data/repositories/device_image_repository.dart';
import '../features/evaluations/domain/repositories/evaluation_repository.dart';
import '../features/evaluations/domain/repositories/image_acquisition_repository.dart';
import '../features/evaluations/domain/usecases/create_evaluation.dart';
import '../features/evaluations/domain/usecases/save_evaluation.dart';
import '../features/evaluations/domain/usecases/select_evaluation_image.dart';
import '../features/evaluations/presentation/controllers/evaluations_controller.dart';
import 'session_controller.dart';

/// Composition root: the only place that chooses concrete infrastructure.
class AppDependencies {
  final SessionController session;
  AppDependencies({
    required AuthRepository authRepository,
    required PatientRepository patientRepository,
    required EvaluationRepository evaluationRepository,
    required ImageAcquisitionRepository imageRepository,
    DateTime Function()? now,
    String Function()? newId,
  }) : session = _compose(
         authRepository,
         patientRepository,
         evaluationRepository,
         imageRepository,
         now ?? DateTime.now,
         newId ?? _randomId,
       );

  factory AppDependencies.inMemory({ImageAcquisitionRepository? images}) =>
      AppDependencies(
        authRepository: PreviewAuthRepository(),
        patientRepository: InMemoryPatientRepository(),
        evaluationRepository: InMemoryEvaluationRepository(),
        imageRepository: images ?? DeviceImageRepository(ImagePicker()),
      );

  static final _random = Random.secure();
  static String _randomId() => List.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  static SessionController _compose(
    AuthRepository auth,
    PatientRepository patients,
    EvaluationRepository evaluations,
    ImageAcquisitionRepository images,
    DateTime Function() now,
    String Function() newId,
  ) => SessionController(
    AuthController(SignIn(auth), SignOut(auth)),
    PatientsController(patients, RegisterPatient(patients, now), newId),
    EvaluationsController(
      evaluations,
      CreateEvaluation(patients, newId, now),
      SaveEvaluation(evaluations, patients),
    ),
    SelectEvaluationImage(images),
  );
  void dispose() => session.dispose();
}
