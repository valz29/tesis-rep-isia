import '../../domain/entities/patient.dart';

/// Converts persistence fields without exposing database names to the domain.
abstract final class PatientMapper {
  static Patient fromJson(Map<String, dynamic> row) => Patient(
    id: row['id'] as String,
    dni: row['dni'] as String,
    ownerId: row['owner_id'] as String?,
    ownerName:
        (row['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
    nombres: row['first_names'] as String,
    apellidos: row['last_names'] as String,
    fechaNacimiento: DateTime.parse(row['birth_date'] as String),
    sexo: row['sex'] == 'female' ? Sexo.femenino : Sexo.masculino,
    telefono: row['phone'] as String?,
    direccion: row['address'] as String?,
    historiaClinica: row['medical_history'] as String?,
    isActive: row['is_active'] as bool? ?? true,
    deactivationReason: row['deactivation_reason'] as String?,
  );

  /// Ownership and lifecycle fields are changed only by their authorized RPCs.
  static Map<String, dynamic> editableFields(Patient patient) => {
    'dni': patient.dni,
    'first_names': patient.nombres,
    'last_names': patient.apellidos,
    'birth_date': _dateOnly(patient.fechaNacimiento),
    'sex': patient.sexo == Sexo.femenino ? 'female' : 'male',
    'phone': patient.telefono,
    'address': patient.direccion,
    'medical_history': patient.historiaClinica,
  };

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
