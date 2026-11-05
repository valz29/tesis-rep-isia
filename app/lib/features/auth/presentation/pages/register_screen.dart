import '../validators/input_validators.dart';

import 'package:rd_app/app/app_scope.dart';

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
  final _nombre = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;
  final _password = TextEditingController();
  final _correo = TextEditingController();
  bool _hidden = true;
  bool _confirmHidden = true;
  @override
  void dispose() {
    _nombre.dispose();
    _password.dispose();
    _correo.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = AppScope.of(context).auth;
    final result = await auth.register(
      _nombre.text,
      _correo.text,
      _password.text,
    );
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _busy = false;
        _error = auth.error;
      });
      return;
    }
    _password.clear();
    setState(() {
      _busy = false;
      _sent = true;
    });
  }

  Future<void> _reenviar() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = AppScope.of(context).auth;
    final ok = await auth.resendConfirmation(_correo.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok
          ? 'Si la cuenta está pendiente, recibirás un nuevo enlace. Revisa también spam.'
          : auth.error;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registrarse')),
    body: PageBody(
      children: [
        if (_sent) ...[
          const Icon(
            Icons.mark_email_read_outlined,
            size: 64,
            color: AppTheme.primario,
          ),
          const SizedBox(height: 24),
          const Text(
            'Confirma tu correo para activar tu cuenta.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Aún no puedes ingresar. Abre el enlace que enviamos a tu correo desde este teléfono. Revisa también spam.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => AppRoutes.registered(context, _correo.text.trim()),
            child: const Text('Ya confirmé mi correo · Iniciar sesión'),
          ),
          TextButton(
            onPressed: _busy ? null : _reenviar,
            child: Text(_busy ? 'Enviando...' : 'Reenviar enlace'),
          ),
          if (_error != null) Text(_error!, textAlign: TextAlign.center),
        ] else ...[
          const SizedBox(height: 24),
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _nombre,
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
                  validator: (v) => v == null || v.length < 8
                      ? 'Usa al menos 8 caracteres'
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
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_error!),
            ),
          FilledButton(
            onPressed: _busy ? null : _registrar,
            child: Text(_busy ? 'Creando cuenta...' : 'Registrarse'),
          ),
          const SizedBox(height: 20),
          const Text('¿Ya tienes una cuenta?', textAlign: TextAlign.center),
          TextButton(
            onPressed: () => AppRoutes.registered(context, ''),
            child: const Text('Iniciar sesión'),
          ),
        ],
      ],
    ),
  );
}
