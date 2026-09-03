/// Caso de uso: obtener el usuario autenticado (RF-01.3).
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class GetCurrentUserUseCase {
  GetCurrentUserUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<User>> call() async {
    try {
      return Result.success<User>(await _repository.getCurrentUser());
    } on Failure catch (failure) {
      return Result.failure<User>(failure);
    }
  }
}
