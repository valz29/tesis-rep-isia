import '../../domain/entities/auth_session_event.dart';
import '../../domain/entities/staff_member.dart';
import '../../domain/repositories/auth_repository.dart';

/// Used only by explicitly injected in-memory dependencies and tests.
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
  Future<RegistrationOutcome> register(
    String name,
    String email,
    String password,
  ) async => const RegistrationOutcome(needsConfirmation: true);
  @override
  Future<StaffMember?> currentStaff() async => null;
  @override
  Stream<AuthSessionEvent> get sessionChanges => const Stream.empty();
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> resendConfirmation(String email) async {}
  @override
  Future<void> updatePassword(String password) async {}
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signOut() async {}
}
