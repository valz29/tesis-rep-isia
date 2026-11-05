import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_failures.dart';
import '../../domain/entities/admin_account.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../../auth/domain/entities/staff_member.dart';
import '../../../evaluations/domain/entities/evaluation_draft.dart';

class SupabaseAdminRepository implements AdminRepository {
  final SupabaseClient client;
  SupabaseAdminRepository(this.client);
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw supabaseFailure(
        e,
        'No se pudo completar la operación de administración',
      );
    }
  }

  @override
  Future<AdminOverview> overview() => _guard(() async {
    final r = await client.rpc('admin_overview') as Map<String, dynamic>;
    return AdminOverview(
      users: (r['users'] as num).toInt(),
      unconfirmed: (r['unconfirmed'] as num).toInt(),
      inactive: (r['inactive'] as num).toInt(),
      patients: (r['patients'] as num).toInt(),
      evaluations: (r['evaluations'] as num).toInt(),
      drafts: (r['drafts'] as num).toInt(),
    );
  });
  @override
  Future<List<AdminAccount>> users(String query, int offset) =>
      _guard(() async {
        final rows = await client.rpc(
          'admin_list_users',
          params: {'query_input': query, 'offset_input': offset},
        ) as List;
        return rows
            .map(
              (r) => AdminAccount(
                id: r['id'],
                name: r['full_name'] ?? 'Sin nombre',
                email: r['email'] ?? '',
                role: r['role'] == 'admin'
                    ? AccountRole.admin
                    : AccountRole.professional,
                active: r['is_active'],
                confirmed: r['email_confirmed_at'] != null,
                createdAt: DateTime.parse(r['created_at']).toLocal(),
                lastSignIn: r['last_sign_in_at'] == null
                    ? null
                    : DateTime.parse(r['last_sign_in_at']).toLocal(),
                patientCount: (r['patient_count'] as num).toInt(),
              ),
            )
            .toList();
      });
  @override
  Future<void> updateUser(
    String id,
    String name,
    AccountRole role,
    bool active,
  ) => _guard(() async {
    await client.rpc(
      'admin_update_user',
      params: {
        'user_id_input': id,
        'name_input': name,
        'role_input': role == AccountRole.admin ? 'admin' : 'professional',
        'active_input': active,
      },
    );
  });
  @override
  Future<void> deleteEmptyUser(String id) => _guard(() async {
    await client.rpc('admin_delete_empty_user', params: {'user_id_input': id});
  });
  @override
  Future<void> reassignPatient(String patientId, String ownerId) =>
      _guard(() async {
        await client.rpc(
          'admin_reassign_patient',
          params: {'patient_id_input': patientId, 'owner_id_input': ownerId},
        );
      });
  @override
  Future<void> updateEvaluation(
    String id,
    OjoEvaluado eye,
    String observations,
  ) => _guard(() async {
    await client.rpc(
      'admin_update_evaluation',
      params: {
        'evaluation_id_input': id,
        'eye_input': eye == OjoEvaluado.derecho ? 'right' : 'left',
        'observations_input': observations,
      },
    );
  });
  @override
  Future<List<AdminAuditEntry>> audit(int offset) => _guard(() async {
    final rows = await client
        .from('admin_audit_log')
        .select()
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + 49);
    return rows
        .map(
          (r) => AdminAuditEntry(
            r['actor_id'],
            r['target_id'],
            r['action'],
            DateTime.parse(r['created_at']).toLocal(),
          ),
        )
        .toList();
  });
}
