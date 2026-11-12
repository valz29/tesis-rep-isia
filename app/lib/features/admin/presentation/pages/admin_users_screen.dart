import 'package:flutter/material.dart';

import '../../../../app/session_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_body.dart';
import '../../../auth/domain/entities/staff_member.dart';
import '../../domain/entities/admin_account.dart';
import 'admin_user_edit_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  final SessionController session;
  const AdminUsersScreen({super.key, required this.session});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _query = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.session.isAdmin) {
        widget.session.admin.search(text: '');
      }
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _edit(AdminAccount account) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            AdminUserEditScreen(account: account, session: widget.session),
      ),
    );
    if (!mounted) return;
    await widget.session.admin.search();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    if (!s.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Acceso exclusivo de administración')),
      );
    }
    return ListenableBuilder(
      listenable: s.admin,
      builder: (context, _) {
        final c = s.admin;
        return Scaffold(
          appBar: AppBar(title: const Text('Gestión de usuarios')),
          body: PageBody(
            children: [
              const Text(
                'Administra las cuentas, sus roles y su acceso a Retinazo.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _query,
                decoration: AppTheme.campo(
                  'Buscar nombre o correo',
                  icono: Icons.search,
                ),
                onSubmitted: (v) => c.search(text: v),
              ),
              TextButton.icon(
                onPressed: c.busy
                    ? null
                    : () => c.search(text: _query.text.trim()),
                icon: const Icon(Icons.search),
                label: const Text('Buscar'),
              ),
              if (c.error != null) Text(c.error!),
              if (c.busy) const LinearProgressIndicator(),
              if (!c.busy && c.accounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No se encontraron usuarios'),
                ),
              for (final a in c.accounts)
                Card(
                  child: ListTile(
                    leading: Icon(
                      a.role == AccountRole.admin
                          ? Icons.admin_panel_settings_outlined
                          : Icons.person_outline,
                    ),
                    title: Text(a.name),
                    subtitle: Text(
                      '${a.email}\n${a.role == AccountRole.admin ? 'Administrador' : 'Profesional'} · ${!a.active
                          ? 'Desactivado'
                          : a.confirmed
                          ? 'Correo confirmado'
                          : 'Correo pendiente'}\n${a.patientCount} pacientes a cargo',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: c.busy ? null : () => _edit(a),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: c.busy || c.offset == 0
                        ? null
                        : () => c.search(pageOffset: c.offset - 50),
                    child: const Text('Anterior'),
                  ),
                  Text('Página ${c.offset ~/ 50 + 1}'),
                  TextButton(
                    onPressed: c.busy || c.accounts.length < 50
                        ? null
                        : () => c.search(pageOffset: c.offset + 50),
                    child: const Text('Siguiente'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
