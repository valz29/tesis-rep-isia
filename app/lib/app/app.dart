import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'app_scope.dart';
import 'auth_gate.dart';
import 'dependencies.dart';

/// Dependencies are composed and disposed by the caller (AppBootstrap in production).
class RetinazoApp extends StatelessWidget {
  final AppDependencies dependencies;
  const RetinazoApp({super.key, required this.dependencies});

  @override
  Widget build(BuildContext context) => AppScope(
    session: dependencies.session,
    child: MaterialApp(
      title: 'Retinazo',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: AuthGate(session: dependencies.session),
    ),
  );
}
