/// Bus de eventos «sesión expirada» (RF-01.6).
///
/// Desacopla el interceptor HTTP del controlador de sesión y evita la
/// dependencia circular: interceptor → bus ← SessionController → repositorio
/// → Dio → interceptor.
///
/// Flujo: `AuthInterceptor` detecta un 401 en un endpoint autenticado →
/// `bus.notifySessionExpired()` → `SessionController` escucha el stream →
/// limpia el token y transita a `SessionUnauthenticated(expired)` → el
/// `GoRouter` redirige a Login con el banner «Tu sesión ha expirado».
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionExpiredBus {
  final StreamController<void> _controller =
      StreamController<void>.broadcast();

  /// Emitido por el interceptor HTTP ante un 401 en endpoint autenticado.
  void notifySessionExpired() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  Stream<void> get stream => _controller.stream;

  void dispose() => _controller.close();
}

final Provider<SessionExpiredBus> sessionExpiredBusProvider =
    Provider<SessionExpiredBus>((Ref ref) {
  final SessionExpiredBus bus = SessionExpiredBus();
  ref.onDispose(bus.dispose);
  return bus;
});
