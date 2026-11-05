import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_failures.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/staff_member.dart';
import '../../domain/entities/auth_session_event.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;
  final String redirectUrl;
  SupabaseAuthRepository(this._client, {required this.redirectUrl});

  Future<StaffMember> _profile(User user) async {
    if (user.emailConfirmedAt == null) {
      throw const AppFailure('Confirma tu correo antes de ingresar');
    }
    final row = await _client
        .from('profiles')
        .select('id,full_name,role,is_active')
        .eq('id', user.id)
        .single();
    if (row['is_active'] != true) {
      throw const AppFailure(
        'Tu cuenta está desactivada. Contacta al administrador',
      );
    }
    final role = switch (row['role']) {
      'admin' => AccountRole.admin,
      'professional' => AccountRole.professional,
      _ => throw const AppFailure('Tu cuenta no tiene un rol válido'),
    };
    return StaffMember(
      id: user.id,
      usuario: user.email ?? '',
      nombre: (row['full_name'] as String?) ?? 'Usuario',
      role: role,
    );
  }

  @override
  Future<StaffMember> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null || response.session == null) {
        throw const AppFailure('No se pudo iniciar sesión');
      }
      try {
        return await _profile(response.user!);
      } catch (_) {
        await _client.auth.signOut(scope: SignOutScope.local);
        rethrow;
      }
    } catch (e) {
      throw supabaseFailure(e, 'No se pudo iniciar sesión. Revisa tu conexión');
    }
  }

  @override
  Future<RegistrationOutcome> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
        emailRedirectTo: redirectUrl,
      );
      if (response.session != null) {
        await signOut();
        throw const AppFailure(
          'El registro requiere confirmación por correo. Contacta al administrador para revisar la configuración',
        );
      }
      return const RegistrationOutcome(needsConfirmation: true);
    } catch (e) {
      throw supabaseFailure(
        e,
        'No se pudo crear la cuenta. Revisa tu conexión',
      );
    }
  }

  @override
  Future<StaffMember?> currentStaff() async {
    if (_client.auth.currentSession == null) return null;
    try {
      final response = await _client.auth.getUser();
      return response.user == null ? null : await _profile(response.user!);
    } on AuthException catch (e) {
      if ([
            'session_not_found',
            'refresh_token_not_found',
            'refresh_token_already_used',
            'bad_jwt',
          ].contains(e.code) ||
          e.statusCode == '401') {
        await _client.auth.signOut(scope: SignOutScope.local);
        return null;
      }
      throw supabaseFailure(e, 'No se pudo comprobar tu sesión');
    } catch (e) {
      throw supabaseFailure(
        e,
        'No se pudo comprobar tu sesión. Revisa tu conexión',
      );
    }
  }

  @override
  Stream<AuthSessionEvent> get sessionChanges => _client.auth.onAuthStateChange
      .where(
        (state) => [
          AuthChangeEvent.signedIn,
          AuthChangeEvent.signedOut,
          AuthChangeEvent.passwordRecovery,
          AuthChangeEvent.tokenRefreshed,
        ].contains(state.event),
      )
      .map(
        (state) => switch (state.event) {
          AuthChangeEvent.signedOut => AuthSessionEvent.signedOut,
          AuthChangeEvent.passwordRecovery => AuthSessionEvent.passwordRecovery,
          AuthChangeEvent.tokenRefreshed => AuthSessionEvent.tokenRefreshed,
          _ => AuthSessionEvent.signedIn,
        },
      );

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email, redirectTo: redirectUrl);
    } catch (e) {
      throw supabaseFailure(e, 'No se pudo enviar el correo de recuperación');
    }
  }

  @override
  Future<void> resendConfirmation(String email) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: redirectUrl,
      );
    } catch (e) {
      throw supabaseFailure(e, 'No se pudo reenviar el enlace de confirmación');
    }
  }

  @override
  Future<void> updatePassword(String password) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: password));
    } catch (e) {
      throw supabaseFailure(
        e,
        'El enlace venció o no se pudo cambiar la contraseña',
      );
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      throw supabaseFailure(e, 'No se pudo abrir el acceso con Google');
    }
  }

  @override
  Future<void> signOut() async {
    // Device-local sign-out clears persisted credentials even if the network is down.
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      // The SDK clears local credentials before requesting server revocation.
      if (_client.auth.currentSession != null) {
        throw supabaseFailure(e, 'No se pudo cerrar la sesión');
      }
    }
  }
}
