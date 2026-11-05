import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_body.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = AppScope.of(context).auth;
    final ok = await auth.changePassword(_password.text);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = auth.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nueva contraseña')),
    body: PageBody(
      children: [
        const Text('Elige una nueva contraseña para tu cuenta.'),
        const SizedBox(height: 24),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: AppTheme.campo(
                  'Nueva contraseña',
                  icono: Icons.lock_outline,
                ),
                validator: (v) => v == null || v.length < 8
                    ? 'Usa al menos 8 caracteres'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                obscureText: true,
                decoration: AppTheme.campo('Confirmar contraseña'),
                validator: (v) => v != _password.text
                    ? 'Las contraseñas deben coincidir'
                    : null,
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_error!),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Guardar contraseña'),
        ),
        TextButton(
          onPressed: _busy ? null : AppScope.of(context).logout,
          child: const Text('Volver al ingreso'),
        ),
      ],
    ),
  );
}
