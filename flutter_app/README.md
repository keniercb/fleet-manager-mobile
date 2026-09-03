# Módulo RF-01 · Autenticación y sesión — APK Registro de Recorridos

Implementación de la **Fase 1** del plan (`plan-app-registro-recorridos-flutter.md`):
login JWT, bootstrap de sesión, logout, cambio de contraseña y manejo de sesión
expirada, siguiendo la Clean Architecture acordada (Riverpod + Dio + go_router +
flutter_secure_storage).

## Requisitos cubiertos

| Requisito | Implementación | Archivos clave |
|---|---|---|
| **RF-01.1** Login email+password | `POST /api/auth/login` con `skipAuth` | `auth_api.dart`, `login.dart` (use case), `login_screen.dart` |
| **RF-01.2** Token seguro + auto-login | `flutter_secure_storage` + `bootstrap()` al arranque | `token_storage.dart`, `session_controller.dart` |
| **RF-01.3** Perfil/roles al arrancar | `GET /api/auth/me` → `User` + `UserCapabilities` | `user.dart`, `profile_screen.dart`, `home_screen.dart` |
| **RF-01.4** Logout | `POST /api/auth/logout` best-effort + limpieza local garantizada | `auth_repository_impl.dart`, `logout.dart` |
| **RF-01.5** Cambio de contraseña | `PUT /api/auth/cambiar-password` + validaciones cliente y use case | `change_password_controller.dart`, `change_password.dart` |
| **RF-01.6** Sesión expirada | `AuthInterceptor` detecta 401 → bus → estado `expired` → redirect a login con banner | `auth_interceptor.dart`, `session_expired_bus.dart`, `flow_banner.dart` |

## Estructura

```text
lib/
├── main.dart                     # arranque + ProviderScope
├── app.dart                      # MaterialApp.router + tema M3
├── app_router.dart               # go_router con guard de sesión
├── core/
│   ├── config/app_config.dart    # flavors, baseUrl, endpoints, timeouts
│   ├── error/failures.dart       # Failure tipados + mapeo tolerante (R2)
│   ├── error/result.dart         # Either<Failure, T>
│   ├── network/api_client.dart   # Dio central
│   ├── network/auth_interceptor.dart  # Bearer + 401 → bus (RF-01.6)
│   ├── network/session_expired_bus.dart
│   ├── storage/token_storage.dart     # RF-01.2 (Keystore/Keychain + caché)
│   └── utils/validators.dart
└── features/auth/
    ├── auth_providers.dart           # composition root (providers)
    ├── domain/
    │   ├── entities/ (user.dart, auth_session.dart)
    │   ├── repositories/auth_repository.dart   # contrato
    │   └── usecases/ (login, logout, get_current_user, change_password)
    ├── data/
    │   ├── api/auth_api.dart
    │   ├── dto/auth_dtos.dart        # contratos exactos de api-docs.json
    │   └── repositories/auth_repository_impl.dart
    └── presentation/
        ├── controllers/ (session_controller + session_state,
        │                 login_controller, change_password_controller)
        ├── screens/ (splash, login, home, profile, change_password)
        └── widgets/ (app_text_field, flow_banner)
```

## Puesta en marcha

```bash
flutter pub get

# Contra el backend local (emulador Android: localhost = 10.0.2.2)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081

# Contra staging
flutter run --dart-define=API_BASE_URL=https://staging.tu-dominio.cu --dart-define=APP_FLAVOR=staging
```

### Configuración Android imprescindible

1. `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

2. Solo para **debug** contra `http://` (HTTP claro), añadir en la etiqueta
   `application` del manifest de debug:
   `android:usesCleartextTraffic="true"` (o network security config). En
   release usar siempre HTTPS (RNF-03).

## Decisiones y notas de diseño

- **R1 (auth no documentada en el OpenAPI)**: se asume `Authorization: Bearer <token>`
  porque el login devuelve `{token, type, userId, email}`. El interceptor es el
  único punto a tocar si el backend confirma otro esquema.
- **R2 (errores sin schema)**: `failures.dart` parsea RFC-7807 (`detail`),
  Spring (`message`/`error`) y errores por campo; si nada calza, mensaje
  genérico. Los 4xx/5xx nunca crashean la app: siempre `Failure`.
- **Servidor = fuente de verdad**: el cliente no interpreta el JWT; la validez
  se consulta con `/auth/me` (bootstrap) y el backend expira con 401.
- **Sin refresh token (R3)**: al expirar, la sesión termina en el login con el
  banner «Tu sesión ha expirado». El email no se pre-carga a propósito (no
  persistimos PII fuera del token).
- **Fail-open en roles**: `UserCapabilities` es el único punto a ajustar cuando
  se confirmen los nombres reales de roles (`/api/roles`). Mientras tanto no
  bloquea la operación.
- **DTOs a mano**: compilan sin `build_runner`. Cuando se active la generación
  OpenAPI (Fase 0.4) se sustituyen sin cambiar el resto.
- **Logout en dos capas**: el repositorio limpia el token en `finally`
  (garantía local) aunque el backend falle.

## Cómo probar (checklist de Gate F1)

1. App arranca en Splash → sin token → Login.
2. Login con credenciales incorrectas → banner «Credenciales inválidas…».
3. Con servidor caído → banner «Sin conexión…» (NetworkFailure).
4. Login correcto → Home con empresa y roles de `/auth/me`.
5. Cerrar app y reabrir → auto-login directo a Home (token persistido).
6. Perfil → Cambiar contraseña: validar longitud ≥ 6, coincidencia y
   «distinta de la anterior»; el éxito muestra SnackBar y vuelve al perfil.
7. Si el backend invalida el token (o expira) → cualquier request devuelve
   401 → vuelve a Login con banner «Tu sesión ha expirado».
8. Logout → limpieza de token → Login con banner «Sesión cerrada
   correctamente».
