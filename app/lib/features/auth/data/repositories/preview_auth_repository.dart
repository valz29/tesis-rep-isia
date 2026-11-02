import '../../domain/entities/staff_member.dart';
import '../../domain/repositories/auth_repository.dart';

/// Explicit preview implementation, not credential verification or account creation.
class PreviewAuthRepository implements AuthRepository {
  @override
  Future<StaffMember> signIn(String email, String password) async {
    final base = email.split('@').first;
    return StaffMember(
      id: email.toLowerCase(),
      usuario: email,
      nombre: base.isEmpty
          ? 'Personal de salud'
          : base[0].toUpperCase() + base.substring(1),
    );
  }

  @override
  Future<void> signOut() async {}
}
