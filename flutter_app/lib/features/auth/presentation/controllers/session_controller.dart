/// Controlador central de sesión (RF-01.1 → RF-01.6).
///
/// Máquina de estados:
///
///   SessionUnknown ──bootstrap()──▶ SessionBootstrapping
///          │                             │
///          │            ┌────────────────┼─────────────────────┐
///          │            ▼                ▼                     ▼
///          │   SessionUnauthenticated   SessionAuthenticated   SessionBootstrapError
///          │   (reason: initial)        (user + capabilities)  (red/5xx → reintentar)
///          │
///          └── login() ──▶ SessionAuthenticated
///   Authenticated ──logout()──▶ Unauthenticated(loggedOut)
///   Authenticated ──401 (bus)──▶ Unauthenticated(expired)  ← RF-01.6
///
/// El `GoRouter` observa este estado (refreshListenable) y ejecuta los
/// redirects: no hay navegación manual de autenticación.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth_providers.dart';
import '../../../domain/entities/auth_session.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/usecases/get_current_user.dart';
import '../../../domain/usecases/login.dart';
import '../../../domain/usecases/logout.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/session_expired_bus.dart';
import '../../../../core/storage/token_storage.dart';

part 'session_state.dart';

final NotifierProvider<SessionController, SessionState> sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  StreamSubscription<void>? _busSub;

  @override
  SessionState build() {
    // RF-01.6: escucha 401 provenientes del AuthInterceptor.
    final SessionExpiredBus bus = ref.watch(sessionExpiredBusProvider);
    _busSub = bus.stream.listen((_) => onSessionExpired());
    ref.onDispose(() => _busSub?.cancel());

    // Bootstrap automático al arrancar la app (RF-01.2 auto-login).
    Future<void>.microtask(bootstrap);
    return const SessionUnknown();
  }

  late final LoginUseCase _loginUseCase = ref.read(loginUseCaseProvider);
  late final GetCurrentUserUseCase _meUseCase =
      ref.read(getCurrentUserUseCaseProvider);
  late final LogoutUseCase _logoutUseCase = ref.read(logoutUseCaseProvider);

  /// RF-01.2 / RF-01.3 — arranque: ¿hay token? ¿sigue siendo válido?
  Future<void> bootstrap() async {
    state = const SessionBootstrapping();

    final String? token = await ref.read(tokenStorageProvider).read();
    if (token == null || token.isEmpty) {
      state = const SessionUnauthenticated(reason: SessionEndReason.initial);
      return;
    }

    final Result<User> result = await _meUseCase();
    switch (result) {
      case SuccessResult<User>(:final User value):
        state = SessionAuthenticated(
          user: value,
          capabilities: UserCapabilities.fromUser(value),
        );

      case FailureResult<User>(:final Failure failure):
        if (failure is UnauthorizedFailure) {
          // Token caducado/inválido: limpiar y pedir re-login (RF-01.6).
          await ref.read(tokenStorageProvider).clear();
          state = const SessionUnauthenticated(
            reason: SessionEndReason.expired,
          );
        } else if (failure is NetworkFailure ||
            failure is TimeoutFailure ||
            failure is ServerFailure) {
          // No podemos distinguir "servidor caído" de "token inválido":
          // NO borramos el token, ofrecemos reintentar.
          state = SessionBootstrapError(
            'No se pudo verificar la sesión.\n${failure.userMessage}',
          );
        } else {
          await ref.read(tokenStorageProvider).clear();
          state = const SessionUnauthenticated(
            reason: SessionEndReason.initial,
          );
        }
    }
  }

  /// RF-01.1 — usado por `LoginController.submit()`.
  Future<Result<User>> login({
    required String email,
    required String password,
  }) async {
    final Result<AuthSession> loginResult = await _loginUseCase(
      email: email,
      password: password,
    );

    switch (loginResult) {
      case FailureResult<AuthSession>(:final Failure failure):
        return Result.failure<User>(failure);

      case SuccessResult<AuthSession>():
        return _loadUserAndAuthenticate();
    }
  }

  /// RF-01.3 — carga del perfil tras login (o refresh manual del perfil).
  Future<Result<User>> _loadUserAndAuthenticate() async {
    final Result<User> result = await _meUseCase();
    switch (result) {
      case SuccessResult<User>(:final User value):
        state = SessionAuthenticated(
          user: value,
          capabilities: UserCapabilities.fromUser(value),
        );
        return Result.success<User>(value);

      case FailureResult<User>(:final Failure failure):
        if (failure is UnauthorizedFailure) {
          await ref.read(tokenStorageProvider).clear();
          state = const SessionUnauthenticated(
            reason: SessionEndReason.initial,
          );
        }
        return Result.failure<User>(failure);
    }
  }

  /// RF-01.4 — logout local + remoto (best-effort).
  Future<void> logout() async {
    await _logoutUseCase();
    state = const SessionUnauthenticated(reason: SessionEndReason.loggedOut);
  }

  /// RF-01.6 — reacción al 401 del interceptor en endpoints autenticados.
  Future<void> onSessionExpired() async {
    final SessionState current = state;
    final bool shouldExpire = current is SessionAuthenticated ||
        current is SessionBootstrapping ||
        current is SessionUnknown;

    if (shouldExpire) {
      await ref.read(tokenStorageProvider).clear();
      state = const SessionUnauthenticated(reason: SessionEndReason.expired);
    }
  }

  /// Refresh manual del perfil (pull-to-refresh en Pantalla de perfil).
  Future<void> refreshUser() async {
    final SessionState current = state;
    if (current is! SessionAuthenticated) return;

    final Result<User> result = await _meUseCase();
    switch (result) {
      case SuccessResult<User>(:final User value):
        state = SessionAuthenticated(
          user: value,
          capabilities: UserCapabilities.fromUser(value),
        );
      case FailureResult<User>():
        // En refresh silencioso no expulsamos al usuario por un error de red.
        break;
    }
  }
}
