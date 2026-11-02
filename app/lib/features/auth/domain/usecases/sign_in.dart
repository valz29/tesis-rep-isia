import '../../../../core/errors/app_failure.dart';
import '../entities/staff_member.dart';
import '../repositories/auth_repository.dart';

class SignIn {
  final AuthRepository _repository;
  const SignIn(this._repository);
  Future<StaffMember> call(String email, String password) {
    final normalized = email.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized) ||
        password.length < 4) {
      throw const AppFailure('Revisa tu correo y contraseña');
    }
    return _repository.signIn(normalized, password);
  }
}
