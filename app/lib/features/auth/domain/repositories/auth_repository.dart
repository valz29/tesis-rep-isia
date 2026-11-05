import '../entities/staff_member.dart';
import '../entities/auth_session_event.dart';

abstract interface class AuthRepository {
  Future<StaffMember> signIn(String email, String password);
  Future<RegistrationOutcome> register(
    String name,
    String email,
    String password,
  );
  Future<StaffMember?> currentStaff();
  Stream<AuthSessionEvent> get sessionChanges;
  Future<void> sendPasswordReset(String email);
  Future<void> resendConfirmation(String email);
  Future<void> updatePassword(String password);
  Future<void> signInWithGoogle();
  Future<void> signOut();
}
