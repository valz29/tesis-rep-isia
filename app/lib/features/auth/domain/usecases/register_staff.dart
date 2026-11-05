import '../../../../core/errors/app_failure.dart';
import '../entities/auth_session_event.dart';
import '../repositories/auth_repository.dart';

class RegisterStaff {
  final AuthRepository _repository;
  const RegisterStaff(this._repository);
  Future<RegistrationOutcome> call(String name, String email, String password) {
    if (name.trim().isEmpty ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim()) ||
        password.length < 8) {
      throw const AppFailure(
        'Revisa tus datos y usa una contraseña de al menos 8 caracteres',
      );
    }
    return _repository.register(name.trim(), email.trim(), password);
  }
}
