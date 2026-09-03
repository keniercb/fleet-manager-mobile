/// Cliente API del módulo de autenticación (RF-01).
///
/// Endpoints (api-docs.json → tag "Authentication"):
///   POST /api/auth/login            → AuthResponseDto
///   GET  /api/auth/me               → UserResponse
///   POST /api/auth/logout           → 200 (sin cuerpo)
///   PUT  /api/auth/cambiar-password → 200 (sin cuerpo)
///
/// Errores: cualquier respuesta no-2xx lanza `DioException`, que los
/// repositorios convierten a `Failure` con `mapDioError`.
import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../dto/auth_dtos.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  /// RF-01.1 — `skipAuth: true` para no adjuntar token ni disparar
  /// expiración si las credenciales son incorrectas (401 → error de login).
  Future<AuthResponseDto> login(LoginRequestDto body) async {
    final Response<Map<String, dynamic>> res = await _dio.post<Map<String, dynamic>>(
      AppConfig.loginPath,
      data: body.toJson(),
      options: Options(extra: <String, Object?>{'skipAuth': true}),
    );
    return AuthResponseDto.fromJson(res.data ?? <String, dynamic>{});
  }

  /// RF-01.3
  Future<UserResponseDto> getCurrentUser() async {
    final Response<Map<String, dynamic>> res =
        await _dio.get<Map<String, dynamic>>(AppConfig.mePath);
    return UserResponseDto.fromJson(res.data ?? <String, dynamic>{});
  }

  /// RF-01.4 — best-effort: el backend invalida la sesión;
  /// si responde 401 (token ya muerto) no debe disparar expiración otra vez.
  Future<void> logout() async {
    await _dio.post<void>(
      AppConfig.logoutPath,
      options: Options(extra: <String, Object?>{'skipSessionExpired': true}),
    );
  }

  /// RF-01.5 — responde 200 sin cuerpo.
  Future<void> changePassword(CambioPasswordRequestDto body) async {
    await _dio.put<void>(
      AppConfig.changePasswordPath,
      data: body.toJson(),
      options: Options(extra: <String, Object?>{'skipSessionExpired': true}),
    );
  }
}
