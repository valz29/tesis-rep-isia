import '../../../../core/errors/app_failure.dart';
import '../../../auth/domain/entities/staff_member.dart';
import '../repositories/admin_repository.dart';

class UpdateAdminAccount {
  final AdminRepository repository;
  const UpdateAdminAccount(this.repository);
  Future<void> call(
    String id,
    String name,
    AccountRole role,
    bool active,
  ) async {
    if (id.isEmpty || name.trim().isEmpty || name.trim().length > 150) {
      throw const AppFailure('Ingresa un nombre de hasta 150 caracteres');
    }
    await repository.updateUser(id, name.trim(), role, active);
  }
}
