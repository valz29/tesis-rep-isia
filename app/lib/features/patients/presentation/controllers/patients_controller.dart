import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patient_repository.dart';
import '../../domain/usecases/register_patient.dart';
import '../../domain/usecases/update_patient.dart';

class PatientsController extends ChangeNotifier {
  final PatientRepository _repository;
  final RegisterPatient _register;
  final UpdatePatient _update;
  final String Function() _newId;
  List<Patient> _patients = const [];
  List<Patient> get patients => _patients;
  bool _disposed = false;
  int _epoch = 0;
  bool busy = false;
  String? error;
  PatientsController(
    this._repository,
    this._register,
    this._update,
    this._newId,
  );

  List<Patient> search(String query, {bool inactive = false}) =>
      List.unmodifiable(
        _patients.where(
          (p) =>
              p.isActive != inactive &&
              (p.dni.contains(query.trim()) ||
                  p.nombreCompleto.toLowerCase().contains(
                    query.trim().toLowerCase(),
                  )),
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
    final epoch = ++_epoch;
    try {
      final records = await _repository.list();
      if (_disposed || epoch != _epoch) return;
      _patients = records;
      error = null;
    } on AppFailure catch (e) {
      if (!_disposed && epoch == _epoch) error = e.message;
      rethrow;
    } finally {
      _notify();
    }
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
    Patient? existing,
    String? ownerId,
  }) async {
    if (busy) return null;
    final epoch = _epoch;
    busy = true;
    error = null;
    _notify();
    try {
      final p = Patient(
        id: existing?.id ?? _newId(),
        ownerId: existing?.ownerId ?? ownerId,
        ownerName: existing?.ownerName,
        dni: dni,
        nombres: nombres,
        apellidos: apellidos,
        fechaNacimiento: fechaNacimiento,
        sexo: sexo,
        telefono: telefono,
        direccion: direccion,
        historiaClinica: historiaClinica,
        isActive: existing?.isActive ?? true,
        deactivationReason: existing?.deactivationReason,
      );
      if (existing == null) {
        await _register(p);
      } else {
        await _update(p);
      }
      final records = await _repository.list();
      if (_disposed || epoch != _epoch) return null;
      _patients = records;
      return byId(p.id) ?? p;
    } on AppFailure catch (e) {
      error = e.message;
      return null;
    } catch (_) {
      error = 'No se pudo guardar el paciente';
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> clear() async {
    _epoch++;
    await _repository.clear();
    _patients = const [];
    error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }
}
