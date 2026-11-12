import '../../../auth/domain/entities/staff_member.dart';
import '../../../evaluations/domain/entities/evaluation_draft.dart';
import '../entities/admin_account.dart';

abstract interface class AdminRepository {
  Future<AdminOverview> overview();
  Future<List<AdminAccount>> users(String query, int offset);
  Future<List<AdminAccount>> eligibleOwners(String query);
  Future<void> setPatientActive(String patientId, bool active, String reason);
  Future<void> updateUser(
    String id,
    String name,
    AccountRole role,
    bool active,
  );
  Future<void> deleteEmptyUser(String id);
  Future<void> reassignPatient(String patientId, String ownerId);
  Future<void> updateEvaluation(
    String id,
    OjoEvaluado eye,
    String observations,
  );
  Future<List<AdminAuditEntry>> audit(int offset);
}
