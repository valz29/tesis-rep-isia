import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rd_app/core/errors/app_failure.dart';
import 'package:rd_app/features/auth/data/repositories/supabase_auth_repository.dart';

import '../../support/auth_storage.dart';

const userId = '10000000-0000-0000-0000-000000000001';
Map<String, dynamic> user({bool confirmed = true}) => {
  'id': userId,
  'aud': 'authenticated',
  'email': 'test@example.invalid',
  'created_at': '2026-01-01T00:00:00Z',
  'email_confirmed_at': confirmed ? '2026-01-01T00:00:00Z' : null,
  'user_metadata': {'role': 'admin'},
  'app_metadata': {'provider': 'email'},
};
String token() {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment({'alg': 'HS256', 'typ': 'JWT'})}.${segment({'sub': userId, 'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000, 'role': 'authenticated'})}.c3ludGhldGlj';
}

http.Response response(
  http.Request request,
  Object? body, [
  int status = 200,
]) => http.Response(
  jsonEncode(body),
  status,
  request: request,
  headers: {
    'content-type': 'application/json',
    'x-supabase-api-version': '2024-01-01',
  },
);

SupabaseClient clientWith(MockClient transport) => SupabaseClient(
  'https://example.invalid',
  'sb_publishable_test',
  httpClient: transport,
  authOptions: AuthClientOptions(
    autoRefreshToken: false,
    pkceAsyncStorage: MemoryAuthStorage(),
  ),
);

void main() {
  test(
    'Account role comes from protected profile, not editable signup metadata',
    () async {
      final client = clientWith(
        MockClient((request) async {
          if (request.url.path.endsWith('/token')) {
            return response(request, {
              'access_token': token(),
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'test-refresh',
              'user': user(),
            });
          }
          if (request.url.path.endsWith('/profiles')) {
            return response(request, {
              'id': userId,
              'full_name': 'Test professional',
              'role': 'professional',
              'is_active': true,
            });
          }
          return response(request, {}, 404);
        }),
      );
      addTearDown(client.dispose);
      final account = await SupabaseAuthRepository(
        client,
        redirectUrl: 'com.devloop.retinazo://auth-callback/',
      ).signIn('test@example.invalid', 'test-only-password');
      expect(account.isAdmin, isFalse);
      expect(account.id, userId);
    },
  );
  test('Registration requests PKCE email confirmation without sending a privileged role', () async {
    Map<String, dynamic>? payload;
    final client = clientWith(
      MockClient((request) async {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(
          request.url.queryParameters['redirect_to'],
          'com.devloop.retinazo://auth-callback/',
        );
        return response(request, user(confirmed: false));
      }),
    );
    addTearDown(client.dispose);
    final result =
        await SupabaseAuthRepository(
          client,
          redirectUrl: 'com.devloop.retinazo://auth-callback/',
        ).register(
          'Test professional',
          'test@example.invalid',
          'test-only-password',
        );
    expect(result.needsConfirmation, isTrue);
    expect(payload!['data'], {'full_name': 'Test professional'});
    expect(payload!['code_challenge'], isNotEmpty);
  });
  test(
    'Invalid login is translated without exposing server payloads',
    () async {
      final client = clientWith(
        MockClient(
          (request) async => response(request, {
            'code': 'invalid_credentials',
            'msg': 'private server diagnostic',
          }, 400),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabaseAuthRepository(
          client,
          redirectUrl: 'com.devloop.retinazo://auth-callback/',
        ).signIn('test@example.invalid', 'incorrect-test-password'),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            'El correo o la contraseña no son correctos',
          ),
        ),
      );
    },
  );
  test('Unconfirmed login is rejected and no session remains', () async {
    final client = clientWith(
      MockClient((request) async {
        if (request.url.path.endsWith('/logout')) {
          return response(request, {}, 200);
        }
        return response(request, {
          'access_token': token(),
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'test-refresh',
          'user': user(confirmed: false),
        });
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAuthRepository(
      client,
      redirectUrl: 'com.devloop.retinazo://auth-callback/',
    );
    await expectLater(
      repository.signIn('test@example.invalid', 'test-password'),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          'Confirma tu correo antes de ingresar',
        ),
      ),
    );
    expect(client.auth.currentSession, isNull);
  });
  test(
    'Unexpected signup session is discarded instead of entering the app',
    () async {
      final client = clientWith(
        MockClient((request) async {
          if (request.url.path.endsWith('/logout')) {
            return response(request, {}, 200);
          }
          return response(request, {
            'access_token': token(),
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'test-refresh',
            'user': user(),
          });
        }),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabaseAuthRepository(
          client,
          redirectUrl: 'com.devloop.retinazo://auth-callback/',
        ).register('Test', 'test@example.invalid', 'test-password'),
        throwsA(isA<AppFailure>()),
      );
      expect(client.auth.currentSession, isNull);
    },
  );
}
