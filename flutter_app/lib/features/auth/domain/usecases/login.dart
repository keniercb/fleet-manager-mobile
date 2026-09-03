/// Caso de uso: iniciar sesión (RF-01.1).
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  LoginUseCase(this._repository);

  final AuthRepository _repository;

  /// Ejecuta el login. En éxito devuelve la sesión (token ya persistido
  /// por el repositorio — RF-01.2); el `SessionController` cargará después
  /// el perfil con GET /api/auth/me.
  Future<Result<AuthSession>> call({
    required String email,
    required String password,
  }) async {
    try {
      final AuthSession session = await _repository.login(
        email: email,
        password: password,
      );
      return Result.success<AuthSession>(session);
    } on Failure catch (failure) {
      return Result.failure<AuthSession>(failure);
    }
  }
}
