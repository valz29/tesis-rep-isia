import 'package:flutter/material.dart';
import 'package:rd_app/app/app_scope.dart';
import 'package:rd_app/core/theme/app_theme.dart';

import '../validators/input_validators.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});
  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _form = GlobalKey<FormState>();
  bool _revisado = false;
  bool _busy = false;
  String? _error;
  final _email = TextEditingController();
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = AppScope.of(context).auth;
    final ok = await auth.recover(_email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _revisado = ok;
      _error = ok ? null : auth.error;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recuperar acceso')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.lock_reset, size: 64, color: AppTheme.primario),
            const SizedBox(height: 24),
            Text(
              '¿Olvidaste tu contraseña?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),

            const SizedBox(height: 24),
            Form(
              key: _form,
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: AppTheme.campo(
                  'Correo electrónico',
                  icono: Icons.mail_outline,
                ),
                validator: validarCorreo,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: const Text('Continuar'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!),
              ),
            if (_revisado) ...[
              const SizedBox(height: 16),
              const Text(
                'Si existe una cuenta con ese correo, recibirás un enlace para recuperar el acceso.',
                textAlign: TextAlign.center,
              ),
            ],
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver al ingreso'),
            ),
          ],
        ),
      ),
    ),
  );
}
