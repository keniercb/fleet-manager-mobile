/// Router de la app con guards de sesión (Fase 0.2 + RF-01).
///
/// Los redirects dependen del `sessionProvider`. Cada cambio de sesión
/// dispara `refreshListenable` y go_router reevalúa:
///
///   SessionUnknown/Bootstrapping/BootstrapError → sólo se permite `/splash`
///   SessionUnauthenticated                      → sólo se permite `/login`
///   SessionAuthenticated                        → se bloquea `/splash` y `/login`
///
/// Así la navegación manual (botón atrás) nunca saca al usuario de login
/// sin sesión ni lo devuelve a login con sesión activa.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/presentation/controllers/session_controller.dart';
import 'features/auth/presentation/screens/change_password_screen.dart';
import 'features/auth/presentation/screens/home_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/profile_screen.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/recorridos/presentation/screens/recorrido_detail_screen.dart';
import 'features/recorridos/presentation/screens/recorrido_form_screen.dart';
import 'features/recorridos/presentation/screens/recorridos_list_screen.dart';

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  // Notifica a go_router cada transición de sesión.
  final ValueNotifier<int> refreshListenable = ValueNotifier<int>(0);
  ref.listen<SessionState>(
    sessionProvider,
    (SessionState? _, SessionState __) => refreshListenable.value++,
  );
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (BuildContext context, GoRouterState state) {
      final SessionState session = ref.read(sessionProvider);
      final String loc = state.matchedLocation;

      final bool onSplash = loc == '/splash';
      final bool onLogin = loc == '/login';

      return switch (session) {
        SessionUnknown() ||
        SessionBootstrapping() ||
        SessionBootstrapError() =>
          onSplash ? null : '/splash',
        SessionUnauthenticated() => onLogin ? null : '/login',
        SessionAuthenticated() => (onSplash || onLogin) ? '/' : null,
      };
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/perfil',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/perfil/cambiar-password',
        builder: (_, __) => const ChangePasswordScreen(),
      ),

      // ---------------- RF-02 · Recorridos ----------------
      // Todas quedan cubiertas por el guard global de sesión: sólo se
      // alcanzan con SessionAuthenticated (redirect arriba).
      GoRoute(
        path: '/recorridos',
        builder: (_, __) => const RecorridosListScreen(),
      ),
      GoRoute(
        path: '/recorridos/nuevo',
        builder: (_, __) => const RecorridoFormScreen(),
      ),
      GoRoute(
        path: '/recorridos/:id',
        builder: (_, GoRouterState state) => RecorridoDetailScreen(
          id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/recorridos/:id/editar',
        builder: (_, GoRouterState state) => RecorridoFormScreen(
          editarId: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
    ],
  );
});
