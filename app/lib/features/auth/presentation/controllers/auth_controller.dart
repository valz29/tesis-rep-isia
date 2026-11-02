import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/staff_member.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';

class AuthController extends ChangeNotifier {
  final SignIn _signIn;
  final SignOut _signOut;
  StaffMember? personal;
  bool busy = false;
  String? error;
  AuthController(this._signIn, this._signOut);

  Future<bool> login(String email, String password) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
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
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _signOut();
    personal = null;
    error = null;
    notifyListeners();
  }
}
