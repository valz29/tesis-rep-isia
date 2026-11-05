import '../../../auth/domain/entities/staff_member.dart';

class AdminAccount {
  final String id, name, email;
  final AccountRole role;
  final bool active, confirmed;
  final DateTime createdAt;
  final DateTime? lastSignIn;
  final int patientCount;
  const AdminAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    required this.confirmed,
    required this.createdAt,
    this.lastSignIn,
    this.patientCount = 0,
  });
}

class AdminOverview {
  final int users, unconfirmed, inactive, patients, evaluations, drafts;
  const AdminOverview({
    this.users = 0,
    this.unconfirmed = 0,
    this.inactive = 0,
    this.patients = 0,
    this.evaluations = 0,
    this.drafts = 0,
  });
}

class AdminAuditEntry {
  final String actorId, targetId, action;
  final DateTime date;
  const AdminAuditEntry(this.actorId, this.targetId, this.action, this.date);
}
