/// Pantalla: detalle del recorrido (RF-02.5) con datos calculados por el
/// servidor (odómetro inicial, combustible inicial, consumo), bloque de
/// abastecimiento y auditoría. Eliminación con confirmación (RF-02.6),
/// sólo para roles de gestión (RF-01.3 → capabilities).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../auth/presentation/widgets/flow_banner.dart';
import '../../../../core/error/failures.dart';
import '../controllers/recorrido_detail_controller.dart';

final DateFormat _fechaFmt = DateFormat('dd/MM/yyyy');
final DateFormat _fechaHoraFmt = DateFormat('dd/MM/yyyy HH:mm');
final NumberFormat _kmFmt = NumberFormat('#,##0');
final NumberFormat _decFmt = NumberFormat('#,##0.00');

class RecorridoDetailScreen extends ConsumerStatefulWidget {
  const RecorridoDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<RecorridoDetailScreen> createState() =>
      _RecorridoDetailScreenState();
}

class _RecorridoDetailScreenState extends ConsumerState<RecorridoDetailScreen> {
  String? _banner;

  Future<void> _confirmarEliminar() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Eliminar recorrido'),
        content: const Text(
          'Esta acción marcará el recorrido como inactivo. '
          '¿Desea continuar?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      final Failure? failure =
          await ref.read(recorridoDetailProvider(widget.id).notifier).eliminar();
      if (!mounted) return;
      if (failure == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recorrido eliminado')),
        );
        context.pop();
      } else {
        setState(() => _banner = failure.userMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RecorridoDetailState state = ref.watch(recorridoDetailProvider(widget.id));
    final SessionState session = ref.watch(sessionProvider);
    final bool puedeEliminar =
        session is SessionAuthenticated && session.capabilities.canManageFleet;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del recorrido')),
      body: switch (state) {
        RecorridoDetailLoading() =>
          const Center(child: CircularProgressIndicator()),
        RecorridoDetailError(:final failure) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(failure.userMessage, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => ref
                        .read(recorridoDetailProvider(widget.id).notifier)
                        .cargar(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        RecorridoDetailLoaded(:final recorrido) => SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (_banner != null)
                  FlowBanner(
                    message: _banner!,
                    kind: FlowBannerKind.warning,
                    onDismiss: () => setState(() => _banner = null),
                  ),

                // ---------- Cabecera ----------
                Card(
                  elevation: 0,
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: <Widget>[
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          child: const Icon(Icons.route_rounded),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${recorrido.vehiculo?.matricula ?? '—'} · '
                                '${_kmFmt.format(recorrido.kilometros)} km',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${_fechaFmt.format(recorrido.fecha)} · '
                                '${recorrido.chofer?.nombreCompleto ?? 'Sin chofer'}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ---------- Datos calculados (RF-02.5, R7) ----------
                Text(
                  'Calculados por el servidor',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: <Widget>[
                        _FilaDato(
                          label: 'Odómetro inicial',
                          valor: recorrido.odometroInicial == null
                              ? '—'
                              : '${_kmFmt.format(recorrido.odometroInicial!)} km',
                        ),
                        _FilaDato(
                          label: 'Combustible inicial',
                          valor: recorrido.combustibleInicial == null
                              ? '—'
                              : '${_decFmt.format(recorrido.combustibleInicial!)} L',
                        ),
                        _FilaDato(
                          label: 'Consumo',
                          valor: recorrido.consumo == null
                              ? '—'
                              : '${_decFmt.format(recorrido.consumo!)} km/L',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ---------- Datos declarados ----------
                Text(
                  'Datos del recorrido',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: <Widget>[
                        _FilaDato(
                          label: 'Vehículo',
                          valor: recorrido.vehiculo == null
                              ? '—'
                              : '${recorrido.vehiculo!.etiqueta}'
                                  ' (${recorrido.vehiculo!.descripcionFlota})',
                        ),
                        _FilaDato(
                          label: 'Chofer',
                          valor:
                              recorrido.chofer?.nombreCompleto ?? 'Sin chofer',
                        ),
                        _FilaDato(
                          label: 'Fecha',
                          valor: _fechaFmt.format(recorrido.fecha),
                        ),
                        _FilaDato(
                          label: 'Kilómetros',
                          valor: '${_kmFmt.format(recorrido.kilometros)} km',
                        ),
                      ],
                    ),
                  ),
                ),

                // ---------- Abastecimiento (RF-02.2) ----------
                if (recorrido.tieneAbastecimiento) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    'Abastecimiento',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: <Widget>[
                          _FilaDato(
                            label: 'Litros',
                            valor: recorrido.litrosAbastecidos == null
                                ? '—'
                                : '${_decFmt.format(recorrido.litrosAbastecidos!)} L',
                          ),
                          _FilaDato(
                            label: 'Número de chip',
                            valor: recorrido.numeroChip ?? '—',
                          ),
                          _FilaDato(
                            label: 'Lugar',
                            valor: recorrido.lugarAbastecimiento ?? '—',
                          ),
                          _FilaDato(
                            label: 'Tarjeta',
                            valor: recorrido.tarjeta == null
                                ? '—'
                                : '${recorrido.tarjeta!.etiqueta}'
                                    ' · saldo ${_decFmt.format(recorrido.tarjeta!.saldo)}',
                          ),
                          _FilaDato(
                            label: 'Importe',
                            valor: recorrido.importeAbastecido == null
                                ? '—'
                                : _decFmt.format(recorrido.importeAbastecido!),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ---------- Auditoría (RF-02.5) ----------
                const SizedBox(height: 16),
                Text(
                  'Auditoría',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: <Widget>[
                        _FilaDato(
                          label: 'Creado por',
                          valor: recorrido.creadoPor ?? '—',
                        ),
                        _FilaDato(
                          label: 'Fecha creación',
                          valor: recorrido.fechaCreacion == null
                              ? '—'
                              : _fechaHoraFmt.format(recorrido.fechaCreacion!),
                        ),
                        _FilaDato(
                          label: 'Modificado por',
                          valor: recorrido.modificadoPor ?? '—',
                        ),
                        _FilaDato(
                          label: 'Última modificación',
                          valor: recorrido.fechaActualizacion == null
                              ? '—'
                              : _fechaHoraFmt
                                  .format(recorrido.fechaActualizacion!),
                        ),
                        _FilaDato(
                          label: 'Estado',
                          valor: recorrido.activo ? 'Activo' : 'Inactivo',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(
                          '/recorridos/${recorrido.id}/editar',
                        ),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Editar'),
                      ),
                    ),
                    if (puedeEliminar) ...<Widget>[
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                          ),
                          onPressed: _confirmarEliminar,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Eliminar'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
      },
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({required this.label, required this.valor});

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
