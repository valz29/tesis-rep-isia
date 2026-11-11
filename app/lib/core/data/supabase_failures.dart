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
    const patientRules = {
      'Reassign patients before granting administrator role':
          'Reasigna sus pacientes antes de cambiar esta cuenta a administrador',
      'Active verified professional required':
          'Selecciona un profesional activo con correo confirmado',
      'Choose an active verified professional':
          'Selecciona un profesional activo con correo confirmado',
      'Assign an active verified professional before reactivation': 'Asigna un profesional activo con correo confirmado antes de reactivar al paciente',
      'Active patient required':
          'El paciente está desactivado. Su historial se conserva',
      'A deactivation reason is required': 'Indica el motivo de desactivación',
    };
    if (patientRules.containsKey(error.message)) {
      return AppFailure(patientRules[error.message]!);
    }
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
