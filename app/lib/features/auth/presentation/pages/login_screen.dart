import 'package:rd_app/app/router/app_routes.dart';
import 'package:flutter/material.dart';

import 'package:rd_app/app/app_scope.dart';

import '../validators/input_validators.dart';

import 'package:rd_app/core/theme/app_theme.dart';
import 'package:rd_app/shared/widgets/page_body.dart';

class LoginScreen extends StatefulWidget {
  final String? correoInicial;
  const LoginScreen({super.key, this.correoInicial});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();

  bool _ocultar = true;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _usuarioCtrl.text = widget.correoInicial ?? '';
  }

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _contrasenaCtrl.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    final auth = AppScope.of(context).auth;
    final ok = await auth.login(_usuarioCtrl.text, _contrasenaCtrl.text);
    if (!mounted) return;
    setState(() => _cargando = false);
    if (ok) {
      AppRoutes.home(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'No se pudo iniciar sesión')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: PageBody(
        children: [
          const SizedBox(height: 40),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _usuarioCtrl,
                  decoration: AppTheme.campo(
                    'Correo electrónico',
                    icono: Icons.mail_outline,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  validator: validarCorreo,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contrasenaCtrl,
                  obscureText: _ocultar,
                  decoration:
                      AppTheme.campo(
                        'Contraseña',
                        icono: Icons.lock_outline,
                      ).copyWith(
                        suffixIcon: IconButton(
                          tooltip: _ocultar
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          onPressed: () => setState(() => _ocultar = !_ocultar),
                          icon: Icon(
                            _ocultar
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                  onFieldSubmitted: (_) {
                    if (!_cargando) _ingresar();
                  },
                  validator: (v) => v == null || v.length < 4
                      ? 'Usa al menos 4 caracteres'
                      : null,
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _cargando ? null : () => AppRoutes.recovery(context),
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
          ),
          const SizedBox(height: 60),
          FilledButton(
            onPressed: _cargando ? null : _ingresar,
            child: _cargando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Iniciar sesión'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
