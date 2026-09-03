/// Cliente HTTP central (Fase 0.3 del plan).
///
/// Un único `Dio` con:
///  - baseUrl por flavor (`AppConfig.apiBaseUrl`)
///  - timeouts por RNF-04
///  - `AuthInterceptor` (Bearer + detección de sesión expirada)
///
/// Los repositorios nunca crean su propio Dio: piden este via Riverpod.
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'auth_interceptor.dart';

final Provider<Dio> dioProvider = Provider<Dio>((Ref ref) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      // Sólo 2xx es éxito; los demás pasan por `mapDioError`.
      validateStatus: (int? status) =>
          status != null && status >= 200 && status < 300,
    ),
  );

  dio.interceptors.add(ref.watch(authInterceptorProvider));

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        // RNF-03: el log en debug no debe imprimir el header Authorization.
        logPrint: (Object obj) => debugPrint(obj.toString()),
      ),
    );
  }

  return dio;
});
