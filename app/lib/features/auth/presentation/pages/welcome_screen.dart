import 'package:flutter/material.dart';
import 'package:rd_app/app/router/app_routes.dart';
import 'package:rd_app/core/theme/app_theme.dart';
import 'package:rd_app/shared/widgets/retinazo_logo.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Center(child: RetinazoLogo(size: 280)),
                const Text(
                  'Retinazo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primario,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Detección temprana de\nretinopatía diabética',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, color: Colors.black54),
                ),
                const SizedBox(height: 52),
                FilledButton(
                  onPressed: () => AppRoutes.login(context),
                  child: const Text('Iniciar sesión'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => AppRoutes.register(context),
                  child: const Text('Registrarse'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
