import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';

import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';

/// Starts after session listeners exist, including on a cold recovery launch.
class AuthLinkCoordinator {
  final SupabaseClient client;
  final void Function(String) onError;
  final Set<String> _processed = {};
  StreamSubscription<Uri>? _subscription;
  AuthLinkCoordinator(this.client, {required this.onError});
  static bool accepts(Uri uri) {
    final expected = Uri.parse(AppConfig.redirectUrl);
    return uri.scheme == expected.scheme &&
        uri.host == expected.host &&
        (uri.path.isEmpty || uri.path == '/');
  }

  Future<void> start() async {
    final links = AppLinks();
    _subscription = links.uriLinkStream.listen(
      (uri) => unawaited(handle(uri)),
      onError: (_) => onError('No se pudo abrir el enlace de acceso'),
    );
    final initial = await links.getInitialLink();
    if (initial != null) await handle(initial);
  }

  Future<void> handle(Uri uri) async {
    if (!accepts(uri)) return;
    final fingerprint = sha256.convert(utf8.encode(uri.toString())).toString();
    if (!_processed.add(fingerprint)) return;
    try {
      await client.auth.getSessionFromUrl(uri);
    } catch (_) {
      onError('El enlace no es válido o ha vencido. Solicita uno nuevo');
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _processed.clear();
  }
}
