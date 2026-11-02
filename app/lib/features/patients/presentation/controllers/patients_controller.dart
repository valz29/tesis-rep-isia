import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patient_repository.dart';
import '../../domain/usecases/register_patient.dart';

class PatientsController extends ChangeNotifier {
  final PatientRepository _repository;
  final RegisterPatient _register;
  final String Function() _newId;
  List<Patient> _patients = const [];
  List<Patient> get patients => _patients;
  bool busy = false;
  String? error;
  PatientsController(this._repository, this._register, this._newId);

  List<Patient> search(String query) => List.unmodifiable(
    _patients.where(
      (p) =>
          p.dni.contains(query.trim()) ||
          p.nombreCompleto.toLowerCase().contains(query.trim().toLowerCase()),
    ),
  );
  Patient? byId(String id) {
    for (final p in _patients) {
      if (p.id == id) return p;
    }
    return null;
  }

  Patient? byDni(String dni) {
    for (final p in _patients) {
      if (p.dni == dni) return p;
    }
    return null;
  }

  Future<void> load() async {
    _patients = await _repository.list();
    notifyListeners();
  }

  Future<Patient?> register({
    required String dni,
    required String nombres,
    required String apellidos,
    required DateTime fechaNacimiento,
    required Sexo sexo,
    String? telefono,
    String? direccion,
    String? historiaClinica,
  }) async {
    if (busy) return null;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final p = Patient(
        id: _newId(),
        dni: dni,
        nombres: nombres,
        apellidos: apellidos,
        fechaNacimiento: fechaNacimiento,
        sexo: sexo,
        telefono: telefono,
        direccion: direccion,
        historiaClinica: historiaClinica,
      );
      await _register(p);
      _patients = await _repository.list();
      return p;
    } on AppFailure catch (e) {
      error = e.message;
      return null;
    } catch (_) {
      error = 'No se pudo guardar el paciente';
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    await _repository.clear();
    _patients = const [];
    error = null;
    notifyListeners();
  }
}
