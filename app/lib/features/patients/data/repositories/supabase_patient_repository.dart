import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_failures.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patient_repository.dart';

class SupabasePatientRepository implements PatientRepository {
  final SupabaseClient _client;
  SupabasePatientRepository(this._client);
  static const _columns = '*,profiles!patients_owner_id_fkey(full_name)';
  Patient _decode(Map<String, dynamic> row) => Patient(
    id: row['id'] as String,
    dni: row['dni'] as String,
    ownerId: row['owner_id'] as String,
    ownerName:
        (row['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
    nombres: row['first_names'] as String,
    apellidos: row['last_names'] as String,
    fechaNacimiento: DateTime.parse(row['birth_date'] as String),
    sexo: row['sex'] == 'female' ? Sexo.femenino : Sexo.masculino,
    telefono: row['phone'] as String?,
    direccion: row['address'] as String?,
    historiaClinica: row['medical_history'] as String?,
  );
  Map<String, dynamic> _encode(Patient p) => {
    'dni': p.dni,
    'first_names': p.nombres,
    'last_names': p.apellidos,
    'birth_date':
        '${p.fechaNacimiento.year.toString().padLeft(4, '0')}-${p.fechaNacimiento.month.toString().padLeft(2, '0')}-${p.fechaNacimiento.day.toString().padLeft(2, '0')}',
    'sex': p.sexo == Sexo.femenino ? 'female' : 'male',
    'phone': p.telefono,
    'address': p.direccion,
    'medical_history': p.historiaClinica,
  };
  @override
  Future<List<Patient>> list() async {
    try {
      final rows = await _client
          .from('patients')
          .select(_columns)
          .order('created_at', ascending: false);
      return List.unmodifiable(rows.map(_decode));
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
      return row == null ? null : _decode(row);
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
      return row == null ? null : _decode(row);
    } catch (e) {
      throw supabaseFailure(e, 'No se pudo consultar el DNI');
    }
  }

  @override
  Future<void> save(Patient patient) async {
    try {
      await _client.from('patients').insert({
        'id': patient.id,
        ..._encode(patient),
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
          .update(_encode(patient))
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
