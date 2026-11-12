import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_failures.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patient_repository.dart';
import '../models/patient_mapper.dart';

class SupabasePatientRepository implements PatientRepository {
  final SupabaseClient _client;
  SupabasePatientRepository(this._client);
  static const _columns = '*,profiles!patients_owner_id_fkey(full_name)';
  @override
  Future<List<Patient>> list() async {
    try {
      final rows = await _client
          .from('patients')
          .select(_columns)
          .order('created_at', ascending: false);
      return List.unmodifiable(rows.map(PatientMapper.fromJson));
    } catch (e) {
      throw supabaseFailure(e, 'No se pudieron cargar los pacientes');
    }
  }

  @override
  Future<Patient?> findById(String id) async {
    try {
      final row = await _client
          .from('patients')
          .select(_columns)
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : PatientMapper.fromJson(row);
    } catch (e) {
      throw supabaseFailure(e, 'No se pudo consultar el paciente');
    }
  }

  @override
  Future<Patient?> findByDni(String dni, {String? ownerId}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw const AppFailure('Inicia sesión para continuar');
      final row = await _client
          .from('patients')
          .select(_columns)
          .eq('owner_id', ownerId ?? user.id)
          .eq('dni', dni)
          .maybeSingle();
      return row == null ? null : PatientMapper.fromJson(row);
    } catch (e) {
      throw supabaseFailure(e, 'No se pudo consultar el DNI');
    }
  }

  @override
  Future<void> save(Patient patient) async {
    try {
      await _client.from('patients').insert({
        'id': patient.id,
        if (patient.ownerId != null) 'owner_id': patient.ownerId,
        ...PatientMapper.editableFields(patient),
      });
    } catch (e) {
      throw supabaseFailure(e, 'No se pudo guardar el paciente');
    }
  }

  @override
  Future<void> update(Patient patient) async {
    try {
      final rows = await _client
          .from('patients')
          .update(PatientMapper.editableFields(patient))
          .eq('id', patient.id)
          .select('id');
      if (rows.length != 1) {
        throw const AppFailure('No tienes permiso para editar este paciente');
      }
    } catch (e) {
      throw supabaseFailure(e, 'No se pudieron guardar los cambios');
    }
  }

  @override
  Future<void> clear() async {} // Remote rows survive logout.
}
