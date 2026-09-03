/// Caso de uso: cambiar contraseña (RF-01.5).
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

class ChangePasswordUseCase {
  ChangePasswordUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call({
    required int userId,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    // Doble validación (la UI ya valida; el caso de uso es la última barrera).
    if (newPassword.length < 6) {
      return Result.failure<void>(const ValidationFailure(
        userMessage: 'La nueva contraseña debe tener al menos 6 caracteres.',
      ));
    }
    if (newPassword != confirmPassword) {
      return Result.failure<void>(const ValidationFailure(
        userMessage: 'La confirmación no coincide con la nueva contraseña.',
      ));
    }
    if (newPassword == currentPassword) {
      return Result.failure<void>(const ValidationFailure(
        userMessage: 'La nueva contraseña debe ser distinta de la anterior.',
      ));
    }

    try {
      await _repository.changePassword(
        userId: userId,
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      return Result.success<void>(null);
    } on Failure catch (failure) {
      return Result.failure<void>(failure);
    }
  }
}
