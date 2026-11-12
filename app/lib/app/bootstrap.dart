import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_theme.dart';
import 'app.dart';
import 'auth_link_coordinator.dart';
import 'config/app_config.dart';
import 'dependencies.dart';

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});
  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<AppDependencies> _startup = _initialize();
  AppDependencies? _dependencies;
  AuthLinkCoordinator? _links;
  Future<AppDependencies> _initialize() async {
    final config = AppConfig.fromEnvironment();
    if (!config.isValid) {
      throw const FormatException('Missing public configuration');
    }
    final supabase = await Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        detectSessionInUri: false,
      ),
    );
    await _links?.dispose();
    _dependencies?.dispose();
    final dependencies = AppDependencies.remote(
      supabase.client,
      redirectUrl: AppConfig.redirectUrl,
      imageApiUrl: config.imageApiUrl,
      googleEnabled: config.googleEnabled,
    );
    _dependencies = dependencies;
    _links = AuthLinkCoordinator(
      supabase.client,
      onError: dependencies.session.reportLinkError,
    );
    await _links!.start();
    return dependencies;
  }

  @override
  void dispose() {
    unawaited(_links?.dispose());
    _dependencies?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppDependencies>(
    future: _startup,
    builder: (context, snapshot) {
      if (snapshot.hasData) return RetinazoApp(dependencies: snapshot.data!);
      return MaterialApp(
        title: 'Retinazo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 52),
                        const SizedBox(height: 16),
                        const Text(
                          'No se pudo iniciar la conexión de Retinazo.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Revisa la conexión y la configuración del aplicativo.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () =>
                              setState(() => _startup = _initialize()),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        ),
      );
    },
  );
}
