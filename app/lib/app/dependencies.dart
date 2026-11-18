import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/admin/data/supabase_admin_repository.dart';
import '../features/admin/domain/admin_repository.dart';
import '../features/admin/presentation/admin_controller.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/domain/register_staff.dart';
import '../features/auth/domain/sign_in.dart';
import '../features/auth/domain/sign_out.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/evaluations/data/device_image_repository.dart';
import '../features/evaluations/data/image_api_client.dart';
import '../features/evaluations/data/supabase_evaluation_repository.dart';
import '../features/evaluations/domain/create_evaluation.dart';
import '../features/evaluations/domain/evaluation.dart';
import '../features/evaluations/domain/evaluation_repository.dart';
import '../features/evaluations/domain/image_acquisition_repository.dart';
import '../features/evaluations/domain/save_evaluation.dart';
import '../features/evaluations/domain/select_evaluation_image.dart';
import '../features/evaluations/presentation/evaluations_controller.dart';
import '../features/patients/data/supabase_patient_repository.dart';
import '../features/patients/domain/patient_repository.dart';
import '../features/patients/domain/register_patient.dart';
import '../features/patients/domain/update_patient.dart';
import '../features/patients/presentation/patients_controller.dart';
import 'session_controller.dart';

/// Composition root: the only place that chooses concrete infrastructure.
class AppDependencies {
  final SessionController session;
  AppDependencies({
    required AuthRepository authRepository,
    required PatientRepository patientRepository,
    required EvaluationRepository evaluationRepository,
    required ImageAcquisitionRepository imageRepository,
    required AdminRepository adminRepository,
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
         adminRepository,
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
