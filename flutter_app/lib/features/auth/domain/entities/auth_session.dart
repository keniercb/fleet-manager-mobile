/// Sesión autenticada resultante del login (RF-01.1 / RF-01.2).
///
/// Refleja el esquema `AuthResponseDto`:
/// { token, type, userId, email }
class AuthSession {
  const AuthSession({
    required this.token,
    required this.tokenType,
    required this.userId,
    required this.email,
  });

  final String token;
  final String tokenType;
  final int userId;
  final String email;

  /// Header Authorization a usar (asunción R1: el backend devuelve
  /// `type: "Bearer"`; se normaliza por si acaso).
  String get authorizationHeader =>
      '${tokenType.isEmpty ? 'Bearer' : tokenType} $token';
}
