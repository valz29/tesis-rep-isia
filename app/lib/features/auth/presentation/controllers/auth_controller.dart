import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/auth_session_event.dart';
import '../../domain/entities/staff_member.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/register_staff.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';

class AuthController extends ChangeNotifier {
  final SignIn _signIn;
  final SignOut _signOut;
  final RegisterStaff _register;
  final AuthRepository _repository;
  StaffMember? personal;
  bool _disposed = false;
  bool busy = false;
  bool restoring = false;
  bool needsPasswordReset = false;
  String? error;
  AuthController(this._signIn, this._signOut, this._register, this._repository);
  Stream<AuthSessionEvent> get sessionChanges => _repository.sessionChanges;

  Future<bool> login(String email, String password) async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      personal = await _signIn(email, password);
      return true;
    } on AppFailure catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'No se pudo iniciar sesión';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<RegistrationOutcome?> register(
    String name,
    String email,
    String password,
  ) async {
    if (busy) return null;
    busy = true;
    error = null;
    _notify();
    try {
      return await _register(name, email, password);
    } on AppFailure catch (e) {
      error = e.message;
      return null;
    } catch (_) {
      error = 'No se pudo crear la cuenta';
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> restore() async {
    if (restoring || busy) return;
    restoring = true;
    error = null;
    _notify();
    try {
      personal = await _repository.currentStaff();
    } on AppFailure catch (e) {
      personal = null;
      error = e.message;
    } catch (_) {
      personal = null;
      error = 'No se pudo comprobar tu sesión';
    } finally {
      restoring = false;
      _notify();
    }
  }

  Future<bool> recover(String email) async {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim())) {
      error = 'Ingresa un correo electrónico válido';
      _notify();
      return false;
    }
    return _perform(() => _repository.sendPasswordReset(email.trim()));
  }

  Future<bool> changePassword(String password) async {
    if (password.length < 8) {
      error = 'Usa al menos 8 caracteres';
      _notify();
      return false;
    }
    final ok = await _perform(() => _repository.updatePassword(password));
    if (ok) {
      needsPasswordReset = false;
      _notify();
    }
    return ok;
  }

  Future<bool> resendConfirmation(String email) =>
      _perform(() => _repository.resendConfirmation(email));

  Future<bool> google() => _perform(_repository.signInWithGoogle);
  Future<bool> _perform(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      await action();
      return true;
    } on AppFailure catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'No se pudo completar la solicitud';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  void markRecovery() {
    needsPasswordReset = true;
    _notify();
  }

  void clearLocal() {
    personal = null;
    needsPasswordReset = false;
    error = null;
    _notify();
  }

  Future<void> logout() async {
    await _signOut();
    clearLocal();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
