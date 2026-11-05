import 'package:flutter/material.dart';

import '../../../../app/session_controller.dart';
import '../../../../shared/widgets/page_body.dart';
import '../../domain/entities/admin_account.dart';

class AdminAuditScreen extends StatefulWidget {
  final SessionController session;
  const AdminAuditScreen({super.key, required this.session});
  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> {
  int _offset = 0;
  late Future<List<AdminAuditEntry>> _records = widget.session.admin.audit(0);
  void _load(int offset) => setState(() {
    _offset = offset;
    _records = widget.session.admin.audit(offset);
  });
  String _label(String action) => switch (action) {
    'users.update' => 'Cuenta actualizada',
    'users.delete' => 'Cuenta eliminada',
    'patients.insert' => 'Paciente registrado',
    'patients.update' => 'Paciente actualizado o reasignado',
    'evaluations.insert' => 'Evaluación registrada',
    'evaluations.update' => 'Evaluación corregida',
    _ => action,
  };
  @override
  Widget build(BuildContext context) {
    if (!widget.session.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Acceso exclusivo de administración')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividad administrativa'),
        actions: [
          IconButton(
            onPressed: () => _load(0),
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: FutureBuilder<List<AdminAuditEntry>>(
        future: _records,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => _load(_offset),
                child: const Text('No se pudo cargar. Reintentar'),
              ),
            );
          }
          final rows = s.data!;
          return PageBody(
            children: [
              const Text(
                'Registro de cambios administrativos. Conserva el actor y el registro afectado, sin copiar datos clínicos.',
              ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No hay actividad en esta página'),
                ),
              for (final r in rows)
                Card(
                  child: ListTile(
                    title: Text(_label(r.action)),
                    subtitle: Text(
                      '${r.date.day}/${r.date.month}/${r.date.year} ${r.date.hour}:${r.date.minute.toString().padLeft(2, '0')}\nAdministrador: ${r.actorId}\nRegistro: ${r.targetId}',
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _offset == 0 ? null : () => _load(_offset - 50),
                    child: const Text('Anterior'),
                  ),
                  TextButton(
                    onPressed: rows.length < 50
                        ? null
                        : () => _load(_offset + 50),
                    child: const Text('Siguiente'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
