import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rd_app/app/app_routes.dart';
import 'package:rd_app/app/app_scope.dart';
import 'package:rd_app/core/app_theme.dart';

import 'auth_visuals.dart';
import 'input_validators.dart';

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
      // AuthGate replaces the navigation stack after a successful sign-in.
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'No se pudo iniciar sesión')),
      );
    }
  }

  InputDecoration _decoration(String label, IconData icon) =>
      AppTheme.campo(label, icono: icon).copyWith(
        fillColor: const Color(0xFFF1F7F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDDE9E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primario, width: 1.5),
        ),
      );

  Widget _credentials() => AutofillGroup(
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _usuarioCtrl,
            enabled: !_cargando,
            decoration: _decoration(
              'Correo electrónico',
              Icons.mail_outline,
            ).copyWith(hintText: 'nombre@correo.com'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            validator: validarCorreo,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _contrasenaCtrl,
            enabled: !_cargando,
            obscureText: _ocultar,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            decoration: _decoration('Contraseña', Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                tooltip: _ocultar ? 'Mostrar contraseña' : 'Ocultar contraseña',
                onPressed: _cargando
                    ? null
                    : () => setState(() => _ocultar = !_ocultar),
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
            validator: (v) =>
                v == null || v.length < 4 ? 'Usa al menos 4 caracteres' : null,
          ),
        ],
      ),
    ),
  );

  Widget _loginCard(Animation<double> animation) => AuthReveal(
    animation: animation,
    start: .12,
    end: .64,
    distance: 44,
    child: Container(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F6B6B),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthReveal(
            animation: animation,
            start: .22,
            end: .76,
            distance: 16,
            child: const Column(
              children: [
                Text(
                  'Iniciar sesión',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.tinta,
                    letterSpacing: -.6,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Accede a tu espacio de trabajo',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF647A78), height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          AuthReveal(
            animation: animation,
            start: .32,
            end: .88,
            distance: 18,
            child: _credentials(),
          ),
          AuthReveal(
            animation: animation,
            start: .40,
            end: .90,
            distance: 16,
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _cargando ? null : () => AppRoutes.recovery(context),
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AuthReveal(
            animation: animation,
            start: .52,
            distance: 22,
            child: FilledButton(
              style: authPrimaryButton(),
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
                  : const Text('Ingresar'),
            ),
          ),
          if (AppScope.of(context).googleEnabled) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _cargando
                  ? null
                  : () async {
                      final auth = AppScope.of(context).auth;
                      final ok = await auth.google();
                      if (!mounted || ok) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            auth.error ?? 'No se pudo abrir Google',
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.account_circle_outlined),
              label: const Text('Continuar con Google'),
            ),
          ],
          const SizedBox(height: 20),
          AuthReveal(
            animation: animation,
            start: .56,
            distance: 16,
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  '¿Aún no tienes cuenta?',
                  style: TextStyle(color: Color(0xFF647A78)),
                ),
                TextButton(
                  onPressed: _cargando
                      ? null
                      : () => AppRoutes.register(context),
                  child: const Text('Crear cuenta'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF085C60),
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AuthHeader(child: SizedBox(height: 210)),
          ),
          SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 44).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: AuthEntrance(
                        builder: (context, animation) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AuthReveal(
                              animation: animation,
                              end: .60,
                              scale: true,
                              child: const AuthLogoBadge(size: 112),
                            ),
                            const SizedBox(height: 20),
                            _loginCard(animation),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
