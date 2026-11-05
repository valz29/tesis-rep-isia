import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_failure.dart';

/// Technical payloads and server details must not appear in the UI/logs.
AppFailure supabaseFailure(Object error, String fallback) {
  if (error is AppFailure) return error;
  if (error is AuthException) {
    return AppFailure(switch (error.code) {
      'invalid_credentials' => 'El correo o la contraseña no son correctos',
      'email_not_confirmed' => 'Confirma tu correo antes de ingresar',
      'over_email_send_rate_limit' =>
        'Se alcanzó el límite de correos. Inténtalo más tarde',
      'email_address_not_authorized' =>
        'El envío de correos aún está restringido al equipo del proyecto',
      'user_already_exists' => 'Revisa tu correo o intenta iniciar sesión',
      'weak_password' =>
        'Usa una contraseña más segura, de al menos 8 caracteres',
      _ => fallback,
    });
  }
  if (error is PostgrestException) {
    return AppFailure(switch (error.code) {
      '23505' => 'Ya existe un registro con estos datos',
      '23503' => 'El registro relacionado ya no está disponible',
      '23514' =>
        'Los datos no cumplen las reglas de la evaluación o del paciente',
      '42501' => 'Tu cuenta no tiene permiso para realizar esta acción',
      'PGRST301' => 'La sesión venció. Vuelve a iniciar sesión',
      _ => fallback,
    });
  }
  return AppFailure(fallback);
}
