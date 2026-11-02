import '../validators/input_validators.dart';

import 'package:flutter/material.dart';

import 'package:rd_app/core/theme/app_theme.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});
  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _form = GlobalKey<FormState>();
  bool _revisado = false;
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
              onPressed: () {
                if (_form.currentState!.validate()) {
                  setState(() => _revisado = true);
                }
              },
              child: const Text('Continuar'),
            ),
            if (_revisado) ...[
              const SizedBox(height: 16),
              const Text(
                'La recuperación de acceso aún no está disponible.',
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
