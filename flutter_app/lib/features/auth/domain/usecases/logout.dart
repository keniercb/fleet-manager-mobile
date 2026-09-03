/// Caso de uso: cerrar sesión (RF-01.4).
import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

class LogoutUseCase {
  LogoutUseCase(this._repository);

  final AuthRepository _repository;

  /// Siempre resulta en éxito local: el logout del servidor es best-effort
  /// y el token se limpia en el repositorio (`finally`).
  Future<Result<void>> call() async {
    await _repository.logout();
    return Result.success<void>(null);
  }
}
