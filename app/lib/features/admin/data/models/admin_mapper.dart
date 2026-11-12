import '../../../auth/domain/entities/staff_member.dart';
import '../../domain/entities/admin_account.dart';

/// Shared mapping for administrative queries, including eligible owners.
abstract final class AdminMapper {
  static AdminAccount account(Map<String, dynamic> row) => AdminAccount(
    id: row['id'] as String,
    name: row['full_name'] as String? ?? 'Sin nombre',
    email: row['email'] as String? ?? '',
    role: row['role'] == 'admin' ? AccountRole.admin : AccountRole.professional,
    active: row['is_active'] as bool,
    confirmed: row['email_confirmed_at'] != null,
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    lastSignIn: row['last_sign_in_at'] == null
        ? null
        : DateTime.parse(row['last_sign_in_at'] as String).toLocal(),
    patientCount: (row['patient_count'] as num).toInt(),
  );

  static AdminOverview overview(Map<String, dynamic> row) => AdminOverview(
    users: (row['users'] as num).toInt(),
    unconfirmed: (row['unconfirmed'] as num).toInt(),
    inactive: (row['inactive'] as num).toInt(),
    patients: (row['patients'] as num).toInt(),
    evaluations: (row['evaluations'] as num).toInt(),
    drafts: (row['drafts'] as num).toInt(),
  );

  static AdminAuditEntry auditEntry(Map<String, dynamic> row) =>
      AdminAuditEntry(
        row['actor_id'] as String,
        row['target_id'] as String,
        row['action'] as String,
        DateTime.parse(row['created_at'] as String).toLocal(),
      );
}
