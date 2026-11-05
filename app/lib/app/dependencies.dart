import '../features/evaluations/data/repositories/image_api_client.dart';
import '../features/admin/domain/repositories/admin_repository.dart';
import '../features/admin/data/repositories/supabase_admin_repository.dart';
import '../features/admin/data/repositories/in_memory_admin_repository.dart';
import '../features/admin/presentation/controllers/admin_controller.dart';

import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

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
import '../features/auth/data/repositories/supabase_auth_repository.dart';
import '../features/auth/domain/usecases/register_staff.dart';
import '../features/patients/domain/usecases/update_patient.dart';
import '../features/patients/data/repositories/supabase_patient_repository.dart';
import '../features/evaluations/data/repositories/supabase_evaluation_repository.dart';
import '../features/evaluations/domain/entities/evaluation.dart';

/// Composition root: the only place that chooses concrete infrastructure.
class AppDependencies {
  final SessionController session;
  AppDependencies({
    required AuthRepository authRepository,
    required PatientRepository patientRepository,
    required EvaluationRepository evaluationRepository,
    required ImageAcquisitionRepository imageRepository,
    AdminRepository? adminRepository,
    DateTime Function()? now,
    String Function()? newId,
    EvaluationStatus initialStatus = EvaluationStatus.pendingAnalysis,
    bool googleEnabled = false,
  }) : session = _compose(
         authRepository,
         patientRepository,
         evaluationRepository,
         imageRepository,
         now ?? DateTime.now,
         newId ?? _randomId,
         initialStatus,
         googleEnabled,
         adminRepository ?? InMemoryAdminRepository(),
       );

  factory AppDependencies.inMemory({ImageAcquisitionRepository? images}) =>
      AppDependencies(
        authRepository: PreviewAuthRepository(),
        patientRepository: InMemoryPatientRepository(),
        evaluationRepository: InMemoryEvaluationRepository(),
        imageRepository: images ?? DeviceImageRepository(ImagePicker()),
      );

  factory AppDependencies.remote(
    SupabaseClient client, {
    required String redirectUrl,
    String imageApiUrl = '',
    bool googleEnabled = false,
  }) => AppDependencies(
    adminRepository: SupabaseAdminRepository(client),
    authRepository: SupabaseAuthRepository(client, redirectUrl: redirectUrl),
    patientRepository: SupabasePatientRepository(client),
    evaluationRepository: SupabaseEvaluationRepository(
      client,
      imageApi: imageApiUrl.isEmpty
          ? null
          : ImageApiClient(
              Uri.parse(imageApiUrl),
              () => client.auth.currentSession?.accessToken,
            ),
    ),
    imageRepository: DeviceImageRepository(ImagePicker()),
    initialStatus: EvaluationStatus.draft,
    googleEnabled: googleEnabled,
  );

  static final _random = Random.secure();
  static String _randomId() {
    final bytes = List.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  static SessionController _compose(
    AuthRepository auth,
    PatientRepository patients,
    EvaluationRepository evaluations,
    ImageAcquisitionRepository images,
    DateTime Function() now,
    String Function() newId,
    EvaluationStatus initialStatus,
    bool googleEnabled,
    AdminRepository admin,
  ) => SessionController(
    AuthController(SignIn(auth), SignOut(auth), RegisterStaff(auth), auth),
    PatientsController(
      patients,
      RegisterPatient(patients, now),
      UpdatePatient(patients, now),
      newId,
    ),
    EvaluationsController(
      evaluations,
      CreateEvaluation(patients, newId, now, initialStatus: initialStatus),
      SaveEvaluation(evaluations, patients),
    ),
    SelectEvaluationImage(images),
    googleEnabled: googleEnabled,
    admin: AdminController(admin),
  );
  void dispose() => session.dispose();
}
