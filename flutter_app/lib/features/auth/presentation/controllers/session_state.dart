part of 'session_controller.dart';

/// Estados de la sesión — parte del archivo del controlador para mantener
/// cohesión; el router solo los lee.
enum SessionEndReason { initial, loggedOut, expired }

sealed class SessionState {
  const SessionState();
}

/// Estado inicial antes del primer bootstrap.
class SessionUnknown extends SessionState {
  const SessionUnknown();
}

/// Verificando token contra GET /api/auth/me (o login en curso).
class SessionBootstrapping extends SessionState {
  const SessionBootstrapping();
}

/// RF-01.3 — usuario con perfil y capacidades resueltas.
class SessionAuthenticated extends SessionState {
  const SessionAuthenticated({required this.user, required this.capabilities});

  final User user;
  final UserCapabilities capabilities;
}

/// Sin sesión. [reason] permite a la UI mostrar el banner correcto:
///  - initial:   login normal
///  - loggedOut: «Sesión cerrada correctamente»
///  - expired:   «Tu sesión ha expirado» (RF-01.6)
class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated({this.reason = SessionEndReason.initial});

  final SessionEndReason reason;
}

/// Fallo de red/5xx durante el bootstrap: la app no sabe si el token es
/// válido → pantalla splash con botón Reintentar (no borra el token).
class SessionBootstrapError extends SessionState {
  const SessionBootstrapError(this.message);

  final String message;
}
