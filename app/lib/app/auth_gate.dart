import 'dart:async';

import 'package:flutter/material.dart';

import '../features/auth/presentation/pages/reset_password_screen.dart';
import '../features/auth/presentation/pages/welcome_screen.dart';
import '../features/home/presentation/pages/home_screen.dart';
import 'session_controller.dart';

/// Replaces the complete navigation stack when the authenticated identity changes.
class AuthGate extends StatefulWidget {
  final SessionController session;
  const AuthGate({super.key, required this.session});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.session.initialize(preserveLinkError: true));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      final failure = s.error;
      if (s.initializing || s.loadingData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (failure != null) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(failure, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      if (s.auth.personal == null) {
                        await s.initialize();
                      } else {
                        await s.refreshData();
                      }
                    },
                    child: const Text('Reintentar'),
                  ),
                  TextButton(
                    onPressed: s.logout,
                    child: const Text('Volver al ingreso'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      final key = s.auth.needsPasswordReset
          ? 'recovery'
          : s.auth.personal == null
          ? 'signed-out'
          : '${s.auth.personal!.id}-${s.auth.personal!.role.name}';
      final page = s.auth.needsPasswordReset
          ? const ResetPasswordScreen()
          : s.auth.personal == null
          ? const WelcomeScreen()
          : HomeScreen(sesion: s);
      return Navigator(
        key: ValueKey(key),
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => page),
      );
    },
  );
}
