import 'package:flutter_test/flutter_test.dart';
import 'package:rd_app/features/admin/data/models/admin_mapper.dart';
import 'package:rd_app/features/auth/domain/entities/staff_member.dart';

void main() {
  test(
    'Administrative account preserves protected role and confirmation state',
    () {
      final row = <String, dynamic>{
        'id': 'admin',
        'full_name': null,
        'email': 'admin@example.invalid',
        'role': 'admin',
        'is_active': true,
        'email_confirmed_at': '2026-11-12T12:00:00Z',
        'created_at': '2026-11-12T12:00:00Z',
        'last_sign_in_at': null,
        'patient_count': 0,
      };
      final admin = AdminMapper.account(row);
      expect(admin.role, AccountRole.admin);
      expect(admin.name, 'Sin nombre');
      expect(admin.active, isTrue);
      expect(admin.confirmed, isTrue);
      expect(admin.lastSignIn, isNull);

      final professional = AdminMapper.account({
        ...row,
        'role': 'professional',
        'is_active': false,
        'email_confirmed_at': null,
      });
      expect(professional.role, AccountRole.professional);
      expect(professional.active, isFalse);
      expect(professional.confirmed, isFalse);
    },
  );
}
