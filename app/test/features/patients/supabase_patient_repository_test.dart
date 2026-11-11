import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rd_app/features/patients/data/repositories/supabase_patient_repository.dart';
import 'package:rd_app/features/patients/domain/entities/patient.dart';

void main() {
  test('Patient adapter writes editable fields; clearing session never deletes remote data', () async {
    final writes = <Map<String, dynamic>>[];
    final methods = <String>[];
    const id = '20000000-0000-0000-0000-000000000001';
    final row = {
      'id': id,
      'owner_id': '10000000-0000-0000-0000-000000000001',
      'dni': '00123456',
      'first_names': 'Test',
      'last_names': 'Patient',
      'birth_date': '1980-01-02',
      'sex': 'female',
      'phone': null,
      'address': null,
      'medical_history': null,
      'profiles': {'full_name': 'Owner'},
    };
    final client = SupabaseClient(
      'https://example.invalid',
      'sb_publishable_test',
      httpClient: MockClient((request) async {
        methods.add(request.method);
        if (request.method == 'POST' || request.method == 'PATCH') {
          writes.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            request.method == 'PATCH'
                ? jsonEncode([
                    {'id': id},
                  ])
                : '',
            request.method == 'POST' ? 201 : 200,
            request: request,
          );
        }
        return http.Response(jsonEncode([row]), 200, request: request);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    final repository = SupabasePatientRepository(client);
    final p = Patient(
      id: id,
      dni: '00123456',
      ownerId: 'professional-id',
      nombres: 'Test',
      apellidos: 'Patient',
      fechaNacimiento: DateTime(1980, 1, 2),
      sexo: Sexo.femenino,
    );
    await repository.save(p);
    await repository.update(p);
    await repository.clear();
    final records = await repository.list();
    expect(records.single.dni, '00123456');
    expect(records.single.ownerName, 'Owner');
    expect(writes.first['owner_id'], 'professional-id');
    expect(writes.last.containsKey('owner_id'), isFalse);
    expect(writes.every((body) => !body.containsKey('is_active')), isTrue);
    expect(writes.last.containsKey('id'), isFalse);
    expect(methods, isNot(contains('DELETE')));
  });
}
