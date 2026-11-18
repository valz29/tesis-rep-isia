import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rd_app/app/app_routes.dart';
import 'package:rd_app/core/app_theme.dart';

import 'auth_visuals.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: AppTheme.primario,
      body: SafeArea(
        bottom: false,
        child: ColoredBox(
          color: AppTheme.fondo,
          child: AuthEntrance(
            builder: (context, animation) => LayoutBuilder(
              builder: (context, constraints) {
                final extraTextHeight =
                    (MediaQuery.textScalerOf(context).scale(36) - 36) * 3;
                final heroHeight =
                    (constraints.maxHeight * .7).clamp(390.0, 680.0) +
                    extraTextHeight;
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      children: [
                        AuthHeader(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: double.infinity,
                              minHeight: heroHeight,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                28,
                                24,
                                28,
                                68,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AuthReveal(
                                    animation: animation,
                                    end: .60,
                                    scale: true,
                                    child: const AuthLogoBadge(),
                                  ),
                                  const SizedBox(height: 24),
                                  AuthReveal(
                                    animation: animation,
                                    start: .20,
                                    end: .72,
                                    child: const Text(
                                      'Retinazo',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  AuthReveal(
                                    animation: animation,
                                    start: .34,
                                    end: .86,
                                    child: const Text(
                                      'Captura y gestión de imágenes\nde fondo de ojo',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        height: 1.5,
                                        color: Color(0xFFE2F4EF),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        AuthReveal(
                          animation: animation,
                          start: .52,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              28,
                              20,
                              28,
                              28 + MediaQuery.paddingOf(context).bottom,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FilledButton(
                                    style: authPrimaryButton(),
                                    onPressed: () => AppRoutes.login(context),
                                    child: const Text('Iniciar sesión'),
                                  ),
                                  const SizedBox(height: 14),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(56),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: () =>
                                        AppRoutes.register(context),
                                    child: const Text('Crear cuenta'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
