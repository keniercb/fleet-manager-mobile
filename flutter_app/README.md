# Módulo RF-01 + RF-02 — APK Registro de Recorridos

Implementación de las **Fases 1–2** del plan (`plan-app-registro-recorridos-flutter.md`):

- **RF-01 · Autenticación y sesión**: login JWT, bootstrap, logout, cambio de contraseña, sesión expirada.
- **RF-02 · Registro de recorridos (núcleo del negocio)**: lista paginada, formulario con abastecimiento opcional, detalle con calculados del servidor, edición/borrado y **outbox offline v1** (Fase 2.5).

Arquitectura: Clean Architecture con Riverpod + Dio + go_router + flutter_secure_storage.

## Requisitos cubiertos

| Requisito | Implementación | Archivos clave |
|---|---|---|
| **RF-01.1** Login email+password | `POST /api/auth/login` con `skipAuth` | `auth_api.dart`, `login.dart` (use case), `login_screen.dart` |
| **RF-01.2** Token seguro + auto-login | `flutter_secure_storage` + `bootstrap()` al arranque | `token_storage.dart`, `session_controller.dart` |
| **RF-01.3** Perfil/roles al arrancar | `GET /api/auth/me` → `User` + `UserCapabilities` | `user.dart`, `profile_screen.dart`, `home_screen.dart` |
| **RF-01.4** Logout | `POST /api/auth/logout` best-effort + limpieza local garantizada | `auth_repository_impl.dart`, `logout.dart` |
| **RF-01.5** Cambio de contraseña | `PUT /api/auth/cambiar-password` + validaciones cliente y use case | `change_password_controller.dart`, `change_password.dart` |
| **RF-01.6** Sesión expirada | `AuthInterceptor` detecta 401 → bus → estado `expired` → redirect a login con banner | `auth_interceptor.dart`, `session_expired_bus.dart`, `flow_banner.dart` |

### RF-02 · Registro de recorridos

| Requisito | Implementación | Archivos clave |
|---|---|---|
| **RF-02.1** Formulario de registro | Vehículo/chofer/fecha (default hoy)/km; pre-selección heurística si hay un único vehículo (R9) | `recorrido_form_controller.dart`, `recorrido_form_screen.dart` |
| **RF-02.2** Abastecimiento opcional | Bloque colapsable: litros, chip (≤50), lugar (≤100), tarjeta con saldo, importe | `recorrido_form_controller.dart` |
| **RF-02.3** Validaciones de cliente | km≥1, litros≥0, fecha≤hoy, longitudes máximas + advertencia de odómetro (R7) | `validators.dart`, `odometro_regla.dart` |
| **RF-02.4** Listado paginado | Paginación infinita, pull-to-refresh, `sort=fecha&sortOrder=DESC`, estados vacío/error | `recorridos_list_controller.dart`, `recorridos_list_screen.dart` |
| **RF-02.5** Detalle con calculados | Odómetro/combustible inicial y consumo del servidor + auditoría | `recorrido_detail_controller.dart`, `recorrido_detail_screen.dart` |
| **RF-02.6** Edición y borrado | PUT/DELETE con confirmación; borrado sólo para roles de gestión (403 protegido) | `recorrido_form_screen.dart`, `recorrido_detail_screen.dart` |
| **RF-02.7** Historial filtrable | Filtro por vehículo (`/vehiculo/{id}`) + búsqueda rápida matrícula/chofer client-side | `recorridos_list_controller.dart` |
| **Fase 2.5** Outbox + SyncManager v1 | Creación sin red → cola FIFO cifrada → sync automático al refrescar con red / manual | `outbox_store.dart`, `outbox_controller.dart` |

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
│   ├── utils/page_params.dart    # paginación Spring encapsulada (R5)
│   └── utils/validators.dart     # + validaciones RF-02.3
├── features/auth/
│   ├── auth_providers.dart           # composition root (providers)
│   ├── domain/
│   │   ├── entities/ (user.dart, auth_session.dart)
│   │   ├── repositories/auth_repository.dart   # contrato
│   │   └── usecases/ (login, logout, get_current_user, change_password)
│   ├── data/
│   │   ├── api/auth_api.dart
│   │   ├── dto/auth_dtos.dart        # contratos exactos de api-docs.json
│   │   └── repositories/auth_repository_impl.dart
│   └── presentation/
│       ├── controllers/ (session_controller + session_state,
│       │                 login_controller, change_password_controller)
│       ├── screens/ (splash, login, home, profile, change_password)
│       └── widgets/ (app_text_field, flow_banner)
└── features/recorridos/            # ★ RF-02 núcleo del negocio
    ├── recorridos_providers.dart       # composition root
    ├── domain/
    │   ├── entities/ (recorrido.dart, flota.dart, page.dart)
    │   ├── repositories/ (recorridos_repository.dart, flota_repository.dart)
    │   ├── services/odometro_regla.dart      # advertencia R7 (pura)
    │   └── usecases/ (listar, obtener, crear, actualizar, eliminar,
    │                 cargar_datos_formulario)
    ├── data/
    │   ├── api/ (recorridos_api.dart, flota_api.dart)
    │   ├── dto/ (recorrido_dtos.dart, flota_dtos.dart)
    │   ├── local/outbox_store.dart           # cola FIFO cifrada (Fase 2.5)
    │   └── repositories/ (recorridos_repository_impl.dart, flota_repository_impl.dart)
    └── presentation/
        ├── controllers/ (recorridos_list_controller, recorrido_form_controller,
        │                 recorrido_detail_controller, outbox_controller)
        └── screens/ (recorridos_list_screen, recorrido_form_screen,
                      recorrido_detail_screen)
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
- **R7 (odómetro)**: el cliente nunca calcula `odometroInicial`/`consumo`;
  los muestra del servidor. Sólo advierte (`OdometroRegla`) cuando los km
  declarados son atípicos (≥1000 km o ≥ odómetro del vehículo).
- **R5 (paginación)**: `PageParams` encapsula `page/perPage/sort/sortOrder`;
  la lista pide `sort=fecha&sortOrder=DESC` (RF-02.4).
- **R9 (pre-selección de vehículo para chofer)**: la API no expone el vínculo
  user↔chofer; si la flota visible tiene un único vehículo activo se
  pre-selecciona; si no, selección manual. Punto único a ajustar en
  `RecorridoFormController.iniciar()` cuando el backend publique el mapeo.
- **Outbox v1 (Fase 2.5)**: sólo la CREACIÓN se encola al fallar por red;
  la cola se persiste cifrada (secure_storage) y se sincroniza FIFO al
  refrescar la lista con red o con «Sincronizar» del banner. Cuando llegue
  Drift (Fase 6) la tabla `outbox` sustituye al store sin cambiar la interfaz.
  Edición/borrado offline llegan con la Fase 6 (conflictos last-write-wins).

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

## Cómo probar RF-02 (checklist de Gate F2)

1. Login → Home → módulo **Recorridos** → lista con recorridos (fecha DESC).
2. «Nuevo» → formulario: elegir vehículo (ver odómetro actual), chofer,
   fecha (el selector no permite fechas futuras) y km.
3. Validaciones: km vacío/0 → error inline; chip >50 o lugar >100 → error;
   km ≥1000 o ≥ odómetro → advertencia ámbar no bloqueante (R7).
4. Guardar → SnackBar y el recorrido aparece primero en la lista.
5. Abrir abastecimiento: litros 0 con importe → error de coherencia;
   seleccionar tarjeta (saldo visible) → guardar con abastecimiento.
6. Detalle → sección «Calculados por el servidor» (odómetro inicial,
   combustible, consumo) y auditoría (creadoPor, fechas).
7. Editar → precarga todo; guardar → PUT y lista actualizada.
8. Eliminar (sólo admin/jefe) → confirmación → DELETE → desaparece de la lista.
9. Filtro por vehículo → la traza muestra `GET /api/recorridos/vehiculo/{id}`;
   búsqueda por matrícula/chofer filtra en cliente.
10. **Gate F2 offline**: con el servidor caído, crear 2–3 recorridos →
    badge «Pendiente de sync» en la lista; reconectar → «Sincronizar» →
    cola FIFO enviada en orden → badges desaparecen y el backend los tiene.
