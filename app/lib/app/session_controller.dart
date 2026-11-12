import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/app_failure.dart';
import '../features/admin/presentation/controllers/admin_controller.dart';
import '../features/auth/domain/entities/auth_session_event.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/evaluations/domain/usecases/select_evaluation_image.dart';
import '../features/evaluations/presentation/controllers/capture_controller.dart';
import '../features/evaluations/presentation/controllers/evaluations_controller.dart';
import '../features/patients/domain/entities/patient.dart';
import '../features/patients/presentation/controllers/patients_controller.dart';

class SessionController extends ChangeNotifier {
  final AuthController auth;
  final AdminController admin;
  final PatientsController patients;
  final EvaluationsController evaluations;
  final SelectEvaluationImage _selectImage;
  final bool googleEnabled;
  StreamSubscription<AuthSessionEvent>? _events;
  bool initializing = false;
  bool loadingData = false;
  bool _disposed = false;
  int _generation = 0;
  String? _loadedFor;
  String? error;
  SessionController(
    this.auth,
    this.patients,
    this.evaluations,
    this._selectImage, {
    this.googleEnabled = false,
    required this.admin,
  }) {
    auth.addListener(_authChanged);
    _events = auth.sessionChanges.listen(
      _sessionEvent,
      onError: (_) {
        if (!_disposed) {
          error = 'No se pudo actualizar la sesión';
          notifyListeners();
        }
      },
    );
  }
  bool get isAdmin => auth.personal?.isAdmin ?? false;
  bool canEdit(Patient patient) =>
      auth.personal != null &&
      (isAdmin || (patient.isActive && patient.ownerId == auth.personal?.id));
  bool canEvaluate(Patient patient) =>
      !isAdmin &&
      patient.isActive &&
      auth.personal != null &&
      patient.ownerId == auth.personal?.id;
  Listenable get changes => Listenable.merge([patients, evaluations]);
  CaptureController createCaptureController() =>
      CaptureController(_selectImage);

  Future<void> initialize({bool preserveLinkError = false}) async {
    if (initializing) return;
    initializing = true;
    if (!preserveLinkError) error = null;
    _notify();
    if (auth.personal == null) await auth.restore();
    error ??= auth.error;
    if (!_disposed) {
      initializing = false;
      _notify();
    }
  }

  void _authChanged() {
    if (_disposed) return;
    final staff = auth.personal;
    final id = staff == null ? null : '${staff.id}:${staff.role.name}';
    if (id != null && id != _loadedFor && !auth.needsPasswordReset) {
      _loadedFor = id;
      unawaited(refreshData());
    }
    _notify();
  }

  Future<void> _sessionEvent(AuthSessionEvent event) async {
    if (_disposed) return;
    switch (event) {
      case AuthSessionEvent.signedOut:
        await _clearLocal();
        if (!_disposed) auth.clearLocal();
      case AuthSessionEvent.passwordRecovery:
        auth.markRecovery();
        await auth.restore();
      case AuthSessionEvent.signedIn:
      case AuthSessionEvent.tokenRefreshed:
        if (!auth.busy) {
          await auth.restore();
          if (auth.error != null) {
            final failure = auth.error;
            await _clearLocal();
            error = failure;
            _notify();
          }
        }
    }
  }

  Future<void> refreshData() async {
    final generation = ++_generation;
    loadingData = true;
    error = null;
    _notify();
    try {
      await patients.load();
      if (generation != _generation || _disposed) return;
      await evaluations.load();
      if (generation != _generation || _disposed) return;
      if (isAdmin) await admin.load();
    } on AppFailure catch (e) {
      if (generation == _generation) error = e.message;
    } catch (_) {
      if (generation == _generation) {
        error = 'No se pudieron cargar los registros. Revisa tu conexión';
      }
    } finally {
      if (generation == _generation && !_disposed) {
        loadingData = false;
        _notify();
      }
    }
  }

  Future<void> _clearLocal() async {
    _generation++;
    _loadedFor = null;
    loadingData = false;
    error = null;
    admin.clear();
    await evaluations.clear();
    await patients.clear();
  }

  Future<void> logout() async {
    await _clearLocal();
    await auth.logout();
  }

  void reportLinkError(String message) {
    error = message;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    auth.removeListener(_authChanged);
    unawaited(_events?.cancel());
    admin.dispose();
    auth.dispose();
    patients.dispose();
    evaluations.dispose();
    super.dispose();
  }
}
