enum AuthSessionEvent { signedIn, signedOut, passwordRecovery, tokenRefreshed }

class RegistrationOutcome {
  final bool needsConfirmation;
  const RegistrationOutcome({required this.needsConfirmation});
}
