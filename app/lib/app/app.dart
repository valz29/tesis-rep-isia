import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'dependencies.dart';
import 'app_scope.dart';
import 'auth_gate.dart';

class RetinazoApp extends StatefulWidget {
  /// Injected dependencies are owned by the caller; defaults belong to the app.
  final AppDependencies? dependencies;
  const RetinazoApp({super.key, this.dependencies});
  @override
  State<RetinazoApp> createState() => _RetinazoAppState();
}

class _RetinazoAppState extends State<RetinazoApp> {
  late final AppDependencies _dependencies =
      widget.dependencies ?? AppDependencies.inMemory();
  @override
  void dispose() {
    if (widget.dependencies == null) _dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    session: _dependencies.session,
    child: MaterialApp(
      title: 'Retinazo',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: AuthGate(session: _dependencies.session),
    ),
  );
}
