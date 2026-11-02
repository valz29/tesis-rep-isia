import '../validators/input_validators.dart';

import 'package:rd_app/app/router/app_routes.dart';
import 'package:flutter/material.dart';

import 'package:rd_app/shared/widgets/page_body.dart';
import 'package:rd_app/core/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _correo = TextEditingController();
  bool _hidden = true;
  bool _confirmHidden = true;
  @override
  void dispose() {
    _password.dispose();
    _correo.dispose();
    super.dispose();
  }

  void _registrar() {
    if (!_form.currentState!.validate()) return;
    AppRoutes.registered(context, _correo.text.trim());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registrarse')),
    body: PageBody(
      children: [
        const SizedBox(height: 24),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                decoration: AppTheme.campo(
                  'Nombre completo',
                  icono: Icons.person_outline,
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Ingresa tu nombre completo'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _correo,
                decoration: AppTheme.campo(
                  'Correo electrónico',
                  icono: Icons.mail_outline,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: validarCorreo,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: _hidden,
                decoration:
                    AppTheme.campo(
                      'Contraseña',
                      icono: Icons.lock_outline,
                    ).copyWith(
                      suffixIcon: IconButton(
                        tooltip: 'Mostrar u ocultar contraseña',
                        onPressed: () => setState(() => _hidden = !_hidden),
                        icon: Icon(
                          _hidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                validator: (v) => v == null || v.length < 4
                    ? 'Usa al menos 4 caracteres'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                obscureText: _confirmHidden,
                decoration:
                    AppTheme.campo(
                      'Confirmar contraseña',
                      icono: Icons.lock_outline,
                    ).copyWith(
                      suffixIcon: IconButton(
                        tooltip: 'Mostrar u ocultar confirmación',
                        onPressed: () =>
                            setState(() => _confirmHidden = !_confirmHidden),
                        icon: Icon(
                          _confirmHidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                validator: (v) => v != _password.text || (v?.isEmpty ?? true)
                    ? 'Las contraseñas deben coincidir'
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        const SizedBox(height: 24),
        FilledButton(onPressed: _registrar, child: const Text('Registrarse')),
        const SizedBox(height: 20),
        const Text('¿Ya tienes una cuenta?', textAlign: TextAlign.center),
        TextButton(
          onPressed: () => AppRoutes.registered(context, ''),
          child: const Text('Iniciar sesión'),
        ),
      ],
    ),
  );
}
