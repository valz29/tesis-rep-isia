import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rd_app/app/auth_link_coordinator.dart';
import 'package:rd_app/app/config/app_config.dart';

void main() {
  test(
    'Mobile configuration rejects privileged keys and invalid destinations',
    () {
      const url = 'https://example.supabase.co';
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'role': 'service_role'})))
          .replaceAll('=', '');
      expect(
        AppConfig(
          url: url,
          publishableKey: 'header.$payload.signature',
        ).isValid,
        isFalse,
      );
      expect(
        const AppConfig(url: url, publishableKey: 'sb_secret_test').isValid,
        isFalse,
      );
      expect(
        const AppConfig(
          url: 'http://example.supabase.co',
          publishableKey: 'sb_publishable_test',
        ).isValid,
        isFalse,
      );
      expect(
        const AppConfig(
          url: url,
          publishableKey: 'sb_publishable_test',
        ).isValid,
        isTrue,
      );
    },
  );
  test('Only the registered auth callback is accepted', () {
    expect(
      AuthLinkCoordinator.accepts(
        Uri.parse('com.devloop.retinazo://auth-callback/?code=test'),
      ),
      isTrue,
    );
    expect(
      AuthLinkCoordinator.accepts(
        Uri.parse('com.devloop.retinazo://other/?code=test'),
      ),
      isFalse,
    );
    expect(
      AuthLinkCoordinator.accepts(
        Uri.parse('https://example.invalid/?code=test'),
      ),
      isFalse,
    );
  });
  test('Image service configuration accepts only an HTTPS origin', () {
    const publicKey = 'sb_publishable_test';
    for (final invalid in [
      'http://localhost:8000',
      'https://user:password@example.com',
      'https://example.com?key=secret',
      'https://example.com/api',
    ]) {
      expect(
        AppConfig(
          url: 'https://example.supabase.co',
          publishableKey: publicKey,
          imageApiUrl: invalid,
        ).isValid,
        isFalse,
      );
    }
    expect(
      const AppConfig(
        url: 'https://example.supabase.co',
        publishableKey: publicKey,
        imageApiUrl: 'https://retinazo-api.example.com',
      ).isValid,
      isTrue,
    );
  });
}
