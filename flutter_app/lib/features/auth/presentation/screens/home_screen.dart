/// Pantalla Home — placeholder de la Fase 2 (Recorridos).
///
/// Para RF-01 muestra: usuario autenticado, capacidades por rol y acceso
/// al perfil. Los módulos de la lista quedan deshabilitados según las
/// capacidades (RF-01.3) y se implementarán en fases posteriores.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/session_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final SessionState session = ref.watch(sessionProvider);

    // El router garantiza que aquí sólo se llega autenticado; si por
    // transición momentánea no lo hay, no dibujamos nada (redirect en curso).
    if (session is! SessionAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final SessionAuthenticated auth = session;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Recorridos'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // ---------- Tarjeta de bienvenida ----------
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      child: Text(
                        auth.user.email.isNotEmpty
                            ? auth.user.email[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            auth.user.empresa?.nombre ?? 'Empresa',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            auth.user.email,
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: auth.user.roleNames
                                .map((String r) => Chip(
                                      visualDensity: VisualDensity.compact,
                                      labelStyle: theme.textTheme.labelSmall,
                                      label: Text(r),
                                    ))
                                .toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---------- Módulos (Fase 2+) ----------
            Text(
              'Módulos',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _ModuleTile(
              icon: Icons.route_rounded,
              title: 'Recorridos',
              subtitle: 'Registrar kilómetros y abastecimientos',
              enabled: auth.capabilities.canRegisterTrips,
              onTap: null, // Fase 2
            ),
            _ModuleTile(
              icon: Icons.directions_car_rounded,
              title: 'Vehículos',
              subtitle: 'Flota, odómetro y mantenimiento',
              enabled: auth.capabilities.canManageFleet,
              onTap: null, // Fase 3
            ),
            _ModuleTile(
              icon: Icons.badge_rounded,
              title: 'Choferes',
              subtitle: 'Personal y licencias',
              enabled: auth.capabilities.canManageFleet,
              onTap: null, // Fase 3
            ),
            _ModuleTile(
              icon: Icons.insert_chart_rounded,
              title: 'Reportes',
              subtitle: 'Consumo, abastecimiento y dashboard',
              enabled: auth.capabilities.canViewReports,
              onTap: null, // Fase 4
            ),
            const SizedBox(height: 16),

            // ---------- Perfil ----------
            OutlinedButton.icon(
              onPressed: () => context.push('/perfil'),
              icon: const Icon(Icons.person_outline_rounded),
              label: const Text('Ver mi perfil'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Desea salir de la aplicación?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(sessionProvider.notifier).logout();
    }
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        enabled: enabled,
        onTap: onTap,
        leading: Icon(icon, color: enabled ? theme.colorScheme.primary : null),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: enabled
            ? const Icon(Icons.chevron_right_rounded)
            : Tooltip(
                message: 'Disponible próximamente',
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
