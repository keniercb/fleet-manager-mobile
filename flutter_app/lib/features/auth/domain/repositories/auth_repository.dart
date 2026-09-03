/// Contrato del repositorio de autenticación (Clean Architecture).
/// La capa `data` lo implementa; la capa `presentation` solo conoce esto.
import '../entities/auth_session.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  /// POST /api/auth/login — RF-01.1
  /// Devuelve la sesión (token incluido) o lanza un [Failure] tipado
  /// (ver `mapDioError` en core/error/failures.dart).
  Future<AuthSession> login({
    required String email,
    required String password,
  });

  /// GET /api/auth/me — RF-01.3
  Future<User> getCurrentUser();

  /// POST /api/auth/logout — RF-01.4 (best-effort: si falla, se limpia local).
  Future<void> logout();

  /// PUT /api/auth/cambiar-password — RF-01.5
  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  });
}
