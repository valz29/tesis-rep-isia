import 'package:rd_app/core/app_failure.dart';
import 'package:rd_app/features/admin/domain/admin_account.dart';
import 'package:rd_app/features/admin/domain/admin_repository.dart';
import 'package:rd_app/features/auth/domain/staff_member.dart';
import 'package:rd_app/features/evaluations/domain/evaluation_draft.dart';

/// Explicit test double; never selected by production bootstrap.
class InMemoryAdminRepository implements AdminRepository {
  final List<AdminAccount> accounts;
  InMemoryAdminRepository([List<AdminAccount>? accounts])
    : accounts = accounts ?? [];
  @override
  Future<AdminOverview> overview() async =>
      AdminOverview(users: accounts.length);
  @override
  Future<List<AdminAccount>> users(String query, int offset) async => accounts
      .where(
        (a) =>
            '${a.name} ${a.email}'.toLowerCase().contains(query.toLowerCase()),
      )
      .skip(offset)
      .take(50)
      .toList();
  @override
  Future<List<AdminAccount>> eligibleOwners(String query) async => accounts
      .where(
        (a) =>
            a.role == AccountRole.professional &&
            a.active &&
            a.confirmed &&
            '${a.name} ${a.email}'.toLowerCase().contains(query.toLowerCase()),
      )
      .take(50)
      .toList();
  @override
  Future<void> setPatientActive(
    String patientId,
    bool active,
    String reason,
  ) async => throw const AppFailure('No disponible en este repositorio');
  @override
  Future<void> updateUser(
    String id,
    String name,
    AccountRole role,
    bool active,
  ) async {
    final i = accounts.indexWhere((a) => a.id == id);
    if (i < 0) throw const AppFailure('Cuenta no disponible');
    final a = accounts[i];
    accounts[i] = AdminAccount(
      id: id,
      name: name,
      email: a.email,
      role: role,
      active: active,
      confirmed: a.confirmed,
      createdAt: a.createdAt,
      patientCount: a.patientCount,
    );
  }

  @override
  Future<void> deleteEmptyUser(String id) async =>
      accounts.removeWhere((a) => a.id == id);
  @override
  Future<void> reassignPatient(String patientId, String ownerId) async =>
      throw const AppFailure('No disponible en este repositorio');
  @override
  Future<void> updateEvaluation(
    String id,
    OjoEvaluado eye,
    String observations,
  ) async => throw const AppFailure('No disponible en este repositorio');
  @override
  Future<List<AdminAuditEntry>> audit(int offset) async => [];
}
