import 'package:flutter/material.dart';

import '../../../../app/session_controller.dart';
import '../../../../shared/widgets/page_body.dart';
import '../../domain/entities/admin_account.dart';

class AdminReassignScreen extends StatefulWidget {
  final String patientId;
  final SessionController session;
  const AdminReassignScreen({
    super.key,
    required this.patientId,
    required this.session,
  });
  @override
  State<AdminReassignScreen> createState() => _AdminReassignScreenState();
}

class _AdminReassignScreenState extends State<AdminReassignScreen> {
  final _query = TextEditingController();
  late Future<List<AdminAccount>> _owners = widget.session.admin.eligibleOwners(
    '',
  );
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _choose(AdminAccount a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reasignar paciente'),
        content: Text(
          '${a.name} (${a.email}) tendrá acceso a este expediente y sus evaluaciones. Se conserva la autoría original de las evaluaciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Reasignar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await widget.session.admin.reassign(widget.patientId, a.id);
    if (!mounted) return;
    if (saved) {
      try {
        await widget.session.patients.load();
      } catch (_) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error =
                'Reasignado. Actualiza la lista para cargar el responsable.';
          });
        }
        return;
      }
      if (mounted) Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error = widget.session.admin.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.session.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Acceso exclusivo de administración')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Responsable del paciente')),
      body: PageBody(
        children: [
          const Text(
            'Elige una cuenta activa con correo confirmado. Busca por nombre o correo si no aparece en los primeros 50 resultados.',
          ),
          TextField(
            controller: _query,
            decoration: const InputDecoration(labelText: 'Buscar responsable'),
            onSubmitted: (v) => setState(
              () => _owners = widget.session.admin.eligibleOwners(v.trim()),
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(
                    () => _owners = widget.session.admin.eligibleOwners(
                      _query.text.trim(),
                    ),
                  ),
            child: const Text('Buscar'),
          ),
          if (_error != null) Text(_error!),
          if (_busy) const LinearProgressIndicator(),
          FutureBuilder<List<AdminAccount>>(
            future: _owners,
            builder: (context, s) {
              if (s.hasError) {
                return const Text('No se pudieron cargar las cuentas');
              }
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Column(
                children: [
                  for (final a in s.data!)
                    ListTile(
                      title: Text(a.name),
                      subtitle: Text(a.email),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : () => _choose(a),
                    ),
                  if (s.data!.isEmpty)
                    const Text('No hay cuentas elegibles para esta búsqueda'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
