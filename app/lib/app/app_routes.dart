import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../features/admin/presentation/admin_audit_screen.dart';
import '../features/admin/presentation/admin_evaluation_screen.dart';
import '../features/admin/presentation/admin_reassign_screen.dart';
import '../features/admin/presentation/admin_users_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/recovery_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/evaluations/domain/evaluation.dart';
import '../features/evaluations/domain/evaluation_draft.dart';
import '../features/evaluations/domain/evaluation_image.dart';
import '../features/evaluations/presentation/capture_screen.dart';
import '../features/evaluations/presentation/eye_selection_screen.dart';
import '../features/evaluations/presentation/history_screen.dart';
import '../features/evaluations/presentation/image_viewer_screen.dart';
import '../features/evaluations/presentation/preparation_screen.dart';
import '../features/evaluations/presentation/result_screen.dart';
import '../features/evaluations/presentation/review_screen.dart';
import '../features/evaluations/presentation/single_image_preview_screen.dart';
import '../features/evaluations/presentation/statistics_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/patients/domain/patient.dart';
import '../features/patients/presentation/patient_detail_screen.dart';
import '../features/patients/presentation/patient_form_screen.dart';
import '../features/patients/presentation/patient_selection_screen.dart';
import 'app_scope.dart';

/// Route construction is centralized; pages don't instantiate other features.
abstract final class AppRoutes {
  static Widget welcomePage() => const WelcomeScreen();
  static Route<T> _route<T>(Widget page) =>
      MaterialPageRoute<T>(builder: (_) => page);
  static Future<void> login(BuildContext c) =>
      Navigator.push(c, _route<void>(const LoginScreen()));
  static Future<void> register(BuildContext c) =>
      Navigator.push(c, _route<void>(const RegisterScreen()));
  static void registered(BuildContext c, String email) =>
      Navigator.pushReplacement(
        c,
        _route<void>(LoginScreen(correoInicial: email)),
      );
  static Future<void> recovery(BuildContext c) =>
      Navigator.push(c, _route<void>(const RecoveryScreen()));
  static void home(BuildContext c) => Navigator.pushAndRemoveUntil(
    c,
    _route<void>(HomeScreen(sesion: AppScope.of(c))),
    (_) => false,
  );
  static void welcome(BuildContext c) => Navigator.pushAndRemoveUntil(
    c,
    _route<void>(const WelcomeScreen()),
    (_) => false,
  );
  static Future<void> adminUsers(BuildContext c) => Navigator.push(
    c,
    _route<void>(AdminUsersScreen(session: AppScope.of(c))),
  );
  static Future<void> adminAudit(BuildContext c) => Navigator.push(
    c,
    _route<void>(AdminAuditScreen(session: AppScope.of(c))),
  );
  static Future<void> adminReassign(BuildContext c, String patientId) =>
      Navigator.push(
        c,
        _route<void>(
          AdminReassignScreen(patientId: patientId, session: AppScope.of(c)),
        ),
      );
  static Future<void> adminEvaluation(BuildContext c, Evaluation e) =>
      Navigator.push(
        c,
        _route<void>(
          AdminEvaluationScreen(evaluation: e, session: AppScope.of(c)),
        ),
      );
  static Future<void> patients(BuildContext c, {bool paraEvaluar = false}) =>
      Navigator.push(
        c,
        _route<void>(
          PatientSelectionScreen(
            sesion: AppScope.of(c),
            paraEvaluar: paraEvaluar,
          ),
        ),
      );
  static Future<Patient?> newPatient(BuildContext c) => Navigator.push(
    c,
    _route<Patient>(PatientFormScreen(sesion: AppScope.of(c))),
  );
  static Future<Patient?> editPatient(BuildContext c, Patient p) =>
      Navigator.push(
        c,
        _route<Patient>(PatientFormScreen(sesion: AppScope.of(c), existing: p)),
      );
  static Future<void> patientDetails(BuildContext c, Patient p) =>
      Navigator.push(
        c,
        _route<void>(
          PatientDetailScreen(patientId: p.id, session: AppScope.of(c)),
        ),
      );
  static Future<void> eye(BuildContext c, Patient p) {
    if (!AppScope.of(c).canEvaluate(p)) return Future.value();
    return Navigator.push(
      c,
      _route<void>(EyeSelectionScreen(paciente: p, sesion: AppScope.of(c))),
    );
  }

  static Future<void> capture(
    BuildContext c,
    Patient p,
    EvaluationDraft draft,
  ) => Navigator.push(
    c,
    _route<void>(
      CaptureScreen(paciente: p, draft: draft, sesion: AppScope.of(c)),
    ),
  );
  static Future<bool?> preview(
    BuildContext c,
    EvaluationImage image,
    int number,
  ) => Navigator.push(
    c,
    _route<bool>(SingleImagePreviewScreen(imagen: image.bytes, numero: number)),
  );
  static Future<void> review(
    BuildContext c,
    Patient p,
    EvaluationDraft draft,
    List<EvaluationImage> images,
  ) => Navigator.push(
    c,
    _route<void>(
      ReviewScreen(
        paciente: p,
        draft: draft,
        sesion: AppScope.of(c),
        imagenes: images,
      ),
    ),
  );
  static void prepare(
    BuildContext c,
    EvaluationDraft draft,
    List<EvaluationImage> images,
  ) => Navigator.pushReplacement(
    c,
    _route<void>(
      PreparationScreen(draft: draft, imagenes: images, sesion: AppScope.of(c)),
    ),
  );
  static void prepared(BuildContext c, Evaluation e) =>
      Navigator.pushReplacement(
        c,
        _route<void>(ResultScreen(evaluacion: e, sesion: AppScope.of(c))),
      );
  static Future<void> result(BuildContext c, Evaluation e) => Navigator.push(
    c,
    _route<void>(
      ResultScreen(evaluacion: e, sesion: AppScope.of(c), desdeHistorial: true),
    ),
  );
  static Future<void> history(BuildContext c) =>
      Navigator.push(c, _route<void>(HistoryScreen(sesion: AppScope.of(c))));
  static Future<void> statistics(BuildContext c) =>
      Navigator.push(c, _route<void>(StatisticsScreen(sesion: AppScope.of(c))));
  static Future<void> image(BuildContext c, Uint8List bytes, String title) =>
      Navigator.push(
        c,
        _route<void>(ImageViewerScreen(imagen: bytes, titulo: title)),
      );
  static void newEvaluation(BuildContext c) {
    if (AppScope.of(c).isAdmin) return;
    Navigator.of(c).popUntil((r) => r.isFirst);
    patients(c, paraEvaluar: true);
  }
}
