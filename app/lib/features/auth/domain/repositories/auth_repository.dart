import '../entities/staff_member.dart';

abstract interface class AuthRepository {
  Future<StaffMember> signIn(String email, String password);
  Future<void> signOut();
}
