import '../entities/patient.dart';

abstract interface class PatientRepository {
  Future<List<Patient>> list();
  Future<Patient?> findById(String id);
  Future<Patient?> findByDni(String dni, {String? ownerId});
  Future<void> save(Patient patient);
  Future<void> update(Patient patient);

  /// Clears device/session caches only. Never deletes remote patient records.
  Future<void> clear();
}
