/// Pantalla de perfil (RF-01.3, RF-01.4, RF-01.5).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/user.dart' show UserCapabilities;
import '../controllers/session_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final SessionState session = ref.watch(sessionProvider);

    if (session is! SessionAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final SessionAuthenticated auth = session;
    final UserCapabilities caps = auth.capabilities;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(sessionProvider.notifier).refreshUser(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // ---------- Identidad ----------
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.primary,
                      child: Text(
                        auth.user.email.isNotEmpty
                            ? auth.user.email[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      auth.user.email,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      avatar: Icon(
                        auth.user.activo
                            ? Icons.check_circle_rounded
                            : Icons.block_rounded,
                        size: 16,
                        color: auth.user.activo
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                      label: Text(auth.user.activo ? 'Activo' : 'Inactivo'),
                      visualDensity: VisualDensity.compact,
                    ),
                    const Divider(height: 24),
                    _DataRow(
                      icon: Icons.business_rounded,
                      label: 'Empresa',
                      value: auth.user.empresa?.nombre ?? '—',
                    ),
                    _DataRow(
                      icon: Icons.tag_rounded,
                      label: 'Código de empresa',
                      value: auth.user.empresa?.codigo ?? '—',
                    ),
                    _DataRow(
                      icon: Icons.badge_rounded,
                      label: 'ID de usuario',
                      value: '${auth.user.id}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---------- Roles y permisos (RF-01.3) ----------
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Roles',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: auth.user.roleNames.isEmpty
                          ? <Widget>[
                              Text('Sin roles asignados',
                                  style: theme.textTheme.bodySmall)
                            ]
                          : auth.user.roleNames
                              .map((String r) => Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(r),
                                    labelStyle: theme.textTheme.labelSmall,
                                  ))
                              .toList(growable: false),
                    ),
                    const SizedBox(height: 12),
                    Text('Capacidades en la app',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 8),
                    _CapabilityRow(
                        text: 'Registrar recorridos',
                        allowed: caps.canRegisterTrips),
                    _CapabilityRow(
                        text: 'Gestionar flota (vehículos, choferes, tarjetas)',
                        allowed: caps.canManageFleet),
                    _CapabilityRow(
                        text: 'Ver reportes', allowed: caps.canViewReports),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ---------- Acciones ----------
            FilledButton.tonalIcon(
              onPressed: () => context.push('/perfil/cambiar-password'),
              icon: const Icon(Icons.password_rounded),
              label: const Text('Cambiar contraseña'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesión'),
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
        content: const Text('Se cerrará la sesión en este dispositivo.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(sessionProvider.notifier).logout();
    }
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('$label: ',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({required this.text, required this.allowed});

  final String text;
  final bool allowed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Icon(
            allowed ? Icons.check_circle_outline_rounded : Icons.highlight_off_rounded,
            size: 18,
            color: allowed ? theme.colorScheme.primary : theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                decoration:
                    allowed ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
