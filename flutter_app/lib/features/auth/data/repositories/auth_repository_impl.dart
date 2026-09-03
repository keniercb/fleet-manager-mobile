/// Implementación del [AuthRepository] sobre Dio + almacenamiento seguro.
///
/// Responsabilidades:
///  - Traducir `DioException` → `Failure` (ADR-06).
///  - Persistir el token al hacer login (RF-01.2) y limpiarlo al logout
///    (RF-01.4), incluso si el logout del servidor falla.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../api/auth_api.dart';
import '../dto/auth_dtos.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required AuthApi api, required TokenStorage tokenStorage})
      : _api = api,
        _tokenStorage = tokenStorage;

  final AuthApi _api;
  final TokenStorage _tokenStorage;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final AuthSession session = await _api
          .login(LoginRequestDto(email: email, password: password))
          .then((AuthResponseDto dto) => dto.toDomain());
      await _tokenStorage.write(session.token); // RF-01.2
      return session;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<User> getCurrentUser() async {
    try {
      final UserResponseDto dto = await _api.getCurrentUser();
      return dto.toDomain();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _api.logout();
    } on DioException catch (e) {
      // Best-effort (RF-01.4): aunque el servidor falle, la sesión local
      // se cierra. Sólo registramos el fallo para observabilidad futura.
      final Failure failure = mapDioError(e);
      assert(() {
        // ignore: avoid_print
        print('logout remoto falló: $failure');
        return true;
      }());
    } finally {
      await _tokenStorage.clear();
    }
  }

  @override
  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await _api.changePassword(CambioPasswordRequestDto(
        userId: userId,
        passwordAnterior: currentPassword,
        nuevaPassword: newPassword,
        confirmacionPassword: confirmPassword,
      ));
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
  return AuthRepositoryImpl(
    api: AuthApi(ref.watch(dioProvider)),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});
