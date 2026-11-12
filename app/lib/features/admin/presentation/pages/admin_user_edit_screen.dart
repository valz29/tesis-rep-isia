import 'package:flutter/material.dart';

import '../../../../app/session_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_body.dart';
import '../../../auth/domain/entities/staff_member.dart';
import '../../domain/entities/admin_account.dart';

class AdminUserEditScreen extends StatefulWidget {
  final AdminAccount account;
  final SessionController session;
  const AdminUserEditScreen({
    super.key,
    required this.account,
    required this.session,
  });
  @override
  State<AdminUserEditScreen> createState() => _AdminUserEditScreenState();
}

class _AdminUserEditScreenState extends State<AdminUserEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.account.name,
  );
  late AccountRole _role = widget.account.role;
  late bool _active = widget.account.active;
  bool _working = false;
  String? _error;
  bool get _self => widget.account.id == widget.session.auth.personal?.id;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_role == AccountRole.admin &&
        widget.account.role != AccountRole.admin) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('¿Conceder acceso de administrador?'),
          content: Text(
            '${widget.account.email} podrá administrar usuarios y todos los expedientes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Conceder acceso'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    final s = widget.session;
    final ok = await s.admin.updateUser(
      widget.account.id,
      _name.text,
      _role,
      _active,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _working = false;
        _error = s.admin.error;
      });
      return;
    }
    // Re-check the acting identity before showing the updated navigation.
    await s.auth.restore();
    if (!mounted) return;
    if (s.auth.personal?.isAdmin == true) await s.admin.load();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    var typed = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Eliminar cuenta definitivamente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Se eliminará ${widget.account.email}. Esta acción no se puede deshacer. Escribe su correo para confirmar. Si tiene registros clínicos, debes desactivarla.',
                ),
                TextField(
                  onChanged: (v) => set(() => typed = v),
                  decoration: const InputDecoration(
                    labelText: 'Correo de la cuenta',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: typed.trim() == widget.account.email
                  ? () => Navigator.pop(c, true)
                  : null,
              child: const Text('Eliminar definitivamente'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || ok != true) return;
    setState(() {
      _working = true;
      _error = null;
    });
    final removed = await widget.session.admin.deleteUser(widget.account.id);
    if (!mounted) return;
    if (removed) {
      await widget.session.admin.load();
      if (mounted) Navigator.pop(context);
    } else {
      setState(() {
        _working = false;
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
    final a = widget.account;
    return Scaffold(
      appBar: AppBar(title: const Text('Administrar cuenta')),
      body: PageBody(
        children: [
          Icon(
            a.role == AccountRole.admin
                ? Icons.admin_panel_settings_outlined
                : Icons.person_outline,
            size: 56,
            color: AppTheme.primario,
          ),
          const SizedBox(height: 16),
          Text(a.email, style: Theme.of(context).textTheme.titleMedium),
          Text(
            a.confirmed
                ? 'Correo confirmado'
                : 'Pendiente de confirmar su correo',
          ),
          Text('Pacientes a cargo: ${a.patientCount}'),
          const SizedBox(height: 24),
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  maxLength: 150,
                  decoration: AppTheme.campo(
                    'Nombre completo',
                    icono: Icons.person_outline,
                  ),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Ingresa el nombre' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AccountRole>(
                  initialValue: _role,
                  decoration: AppTheme.campo(
                    'Rol',
                    icono: Icons.manage_accounts_outlined,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: AccountRole.professional,
                      child: Text('Profesional'),
                    ),
                    DropdownMenuItem(
                      value: AccountRole.admin,
                      enabled: a.confirmed,
                      child: const Text('Administrador'),
                    ),
                  ],
                  onChanged: _self || _working
                      ? null
                      : (v) => setState(() => _role = v!),
                ),
                SwitchListTile(
                  title: const Text('Cuenta activa'),
                  subtitle: const Text(
                    'Desactivarla bloquea el acceso a los datos, conservando sus registros.',
                  ),
                  value: _active,
                  onChanged: _self || _working
                      ? null
                      : (v) => setState(() => _active = v),
                ),
              ],
            ),
          ),
          if (_self)
            const Text(
              'Tu propia cuenta conserva el rol administrador y permanece activa.',
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!),
            ),
          FilledButton(
            onPressed: _working ? null : _save,
            child: Text(_working ? 'Guardando...' : 'Guardar cambios'),
          ),
          if (!_self)
            TextButton.icon(
              onPressed: _working ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Eliminar cuenta sin registros clínicos'),
            ),
          const SizedBox(height: 16),
          const Text(
            'El correo se confirma por su propietario. Las contraseñas no se muestran ni se editan desde este panel.',
          ),
        ],
      ),
    );
  }
}
