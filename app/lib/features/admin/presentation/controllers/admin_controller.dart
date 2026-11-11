import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../auth/domain/entities/staff_member.dart';
import '../../../evaluations/domain/entities/evaluation_draft.dart';
import '../../domain/entities/admin_account.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/usecases/update_admin_account.dart';

class AdminController extends ChangeNotifier {
  final AdminRepository _repository;
  final UpdateAdminAccount _update;
  List<AdminAccount> accounts = const [];
  AdminOverview overview = const AdminOverview();
  bool busy = false;
  String? error;
  String query = '';
  int offset = 0, _epoch = 0, _searchVersion = 0;
  bool _disposed = false;
  AdminController(AdminRepository repository)
    : _repository = repository,
      _update = UpdateAdminAccount(repository);
  Future<void> load() async {
    final epoch = _epoch;
    final result = await _repository.overview();
    if (_disposed || epoch != _epoch) return;
    overview = result;
    _notify();
  }

  Future<void> search({String? text, int? pageOffset}) async {
    if (text != null) {
      query = text;
      offset = 0;
    }
    if (pageOffset != null) offset = pageOffset;
    final epoch = _epoch;
    final version = ++_searchVersion;
    busy = true;
    error = null;
    _notify();
    try {
      final records = await _repository.users(query, offset);
      if (_disposed || epoch != _epoch || version != _searchVersion) return;
      accounts = records;
    } on AppFailure catch (e) {
      if (epoch == _epoch && version == _searchVersion) error = e.message;
    } catch (_) {
      if (epoch == _epoch && version == _searchVersion) {
        error = 'No se pudo cargar la lista de usuarios';
      }
    } finally {
      if (epoch == _epoch && version == _searchVersion) {
        busy = false;
        _notify();
      }
    }
  }

  Future<bool> _perform(Future<void> Function() action) async {
    if (busy) return false;
    final epoch = _epoch;
    busy = true;
    error = null;
    _notify();
    try {
      await action();
      return !_disposed && epoch == _epoch;
    } on AppFailure catch (e) {
      if (epoch == _epoch) error = e.message;
      return false;
    } catch (_) {
      if (epoch == _epoch) error = 'No se pudo completar la operación';
      return false;
    } finally {
      if (epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  Future<bool> updateUser(
    String id,
    String name,
    AccountRole role,
    bool active,
  ) => _perform(() => _update(id, name, role, active));
  Future<bool> deleteUser(String id) =>
      _perform(() => _repository.deleteEmptyUser(id));
  Future<bool> reassign(String patientId, String ownerId) =>
      _perform(() => _repository.reassignPatient(patientId, ownerId));
  Future<bool> setPatientActive(String patientId, bool active, String reason) =>
      _perform(() => _repository.setPatientActive(patientId, active, reason));
  Future<bool> updateEvaluation(
    String id,
    OjoEvaluado eye,
    String observations,
  ) => _perform(() => _repository.updateEvaluation(id, eye, observations));
  Future<List<AdminAuditEntry>> audit(int offset) => _repository.audit(offset);
  Future<List<AdminAccount>> eligibleOwners(String query) =>
      _repository.eligibleOwners(query);
  void clear() {
    _epoch++;
    accounts = const [];
    overview = const AdminOverview();
    error = null;
    busy = false;
    query = '';
    offset = 0;
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
