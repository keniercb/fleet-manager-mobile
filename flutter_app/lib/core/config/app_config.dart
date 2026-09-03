/// Configuración de la aplicación por sabor (flavor) — Fase 0.1 del plan.
///
/// La URL base de la API se inyecta en tiempo de compilación:
///
/// ```bash
/// flutter run \
///   --dart-define=API_BASE_URL=https://staging.midominio.cu \
///   --dart-define=APP_FLAVOR=staging
/// ```
///
/// Nota (R1 del plan): el OpenAPI declara el servidor `http://localhost:8081`
/// pero **no declara `securitySchemes`**. Se asume `Authorization: Bearer <token>`
/// (el login devuelve `token` + `type`). Validar contra el backend real el Día 1.
///
/// En el emulador de Android, `localhost` del host es `10.0.2.2`.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8081',
  );

  static const String flavor = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'dev',
  );

  // Timeouts de red (RNF-04: reintentos con backoff se añaden en Fase 2).
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // Endpoints del módulo de autenticación (api-docs.json → tag "Authentication").
  static const String loginPath = '/api/auth/login';
  static const String logoutPath = '/api/auth/logout';
  static const String mePath = '/api/auth/me';
  static const String changePasswordPath = '/api/auth/cambiar-password';
}
