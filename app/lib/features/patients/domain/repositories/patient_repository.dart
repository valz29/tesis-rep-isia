import '../entities/patient.dart';

abstract interface class PatientRepository {
  Future<List<Patient>> list();
  Future<Patient?> findById(String id);
  Future<Patient?> findByDni(String dni);
  Future<void> save(Patient patient);
  Future<void> clear();
}
