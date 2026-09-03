/// Interceptor de autenticación (RF-01.1 / RF-01.6).
///
/// Responsabilidades:
///  1. Inyectar `Authorization: Bearer <token>` en cada request autenticada.
///  2. Ante un **401 en un endpoint autenticado**, notificar «sesión expirada»
///     vía [SessionExpiredBus] (el `SessionController` escucha y hace logout
///     local + redirect a Login).
///
/// Exclusiones (evitan bucles):
///  - Requests con `extra['skipAuth'] == true` (ej.: el propio login) no
///    llevan token ni disparan expiración.
///  - Requests con `extra['skipSessionExpired'] == true` (ej.: el logout)
///    no disparan expiración aunque respondan 401.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_storage.dart';
import 'session_expired_bus.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required SessionExpiredBus sessionExpiredBus,
  })  : _tokenStorage = tokenStorage,
        _sessionExpiredBus = sessionExpiredBus;

  final TokenStorage _tokenStorage;
  final SessionExpiredBus _sessionExpiredBus;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] != true) {
      final String? token = await _tokenStorage.read();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final RequestOptions request = err.requestOptions;
    final int? status = err.response?.statusCode;

    final bool isAnonymous = request.extra['skipAuth'] == true;
    final bool ignoreExpiry = request.extra['skipSessionExpired'] == true;

    if (status == 401 && !isAnonymous && !ignoreExpiry) {
      // RF-01.6: el backend nos dice que la sesión ya no es válida.
      _sessionExpiredBus.notifySessionExpired();
    }

    handler.next(err);
  }
}

final Provider<AuthInterceptor> authInterceptorProvider =
    Provider<AuthInterceptor>((Ref ref) {
  return AuthInterceptor(
    tokenStorage: ref.watch(tokenStorageProvider),
    sessionExpiredBus: ref.watch(sessionExpiredBusProvider),
  );
});
