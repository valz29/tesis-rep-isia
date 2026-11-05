import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patient_repository.dart';

class InMemoryPatientRepository implements PatientRepository {
  final Map<String, Patient> _records = {};
  @override
  Future<List<Patient>> list() async => List.unmodifiable(_records.values);
  @override
  Future<Patient?> findById(String id) async => _records[id];
  @override
  Future<Patient?> findByDni(String dni, {String? ownerId}) async {
    for (final p in _records.values) {
      if (p.dni == dni && (ownerId == null || p.ownerId == ownerId)) return p;
    }
    return null;
  }

  @override
  Future<void> save(Patient patient) async {
    // Enforce uniqueness at the storage boundary too, even for concurrent calls.
    if (_records.values.any(
      (p) =>
          p.dni == patient.dni &&
          p.ownerId == patient.ownerId &&
          p.id != patient.id,
    )) {
      throw const AppFailure('Este DNI ya está registrado en la sesión');
    }
    _records[patient.id] = patient;
  }

  @override
  Future<void> update(Patient patient) async {
    if (!_records.containsKey(patient.id)) {
      throw const AppFailure('El paciente ya no está disponible');
    }
    await save(patient);
  }

  @override
  Future<void> clear() async => _records.clear();
}
