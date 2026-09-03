/// Pantalla: listado de recorridos (RF-02.4 + RF-02.7).
///
///  - Paginación infinita (página de 10, «Cargar más» automático al fondo).
///  - Pull-to-refresh (RefreshIndicator) + filtro por vehículo + búsqueda
///    rápida por matrícula/chofer.
///  - Ítems del outbox visibles arriba con badge «Pendiente de sync».
///  - Estados: carga (skeleton), vacío, error con Reintentar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../auth/presentation/widgets/flow_banner.dart';
import '../../domain/entities/flota.dart';
import '../../domain/entities/recorrido.dart';
import '../../recorridos_providers.dart' show flotaRepoProvider;
import '../controllers/outbox_controller.dart';
import '../controllers/recorridos_list_controller.dart';

final NumberFormat _kmFmt = NumberFormat('#,##0');
final NumberFormat _decFmt = NumberFormat('#,##0.00');

class RecorridosListScreen extends ConsumerStatefulWidget {
  const RecorridosListScreen({super.key});

  @override
  ConsumerState<RecorridosListScreen> createState() =>
      _RecorridosListScreenState();
}

class _RecorridosListScreenState extends ConsumerState<RecorridosListScreen> {
  @override
  Widget build(BuildContext context) {
    final RecorridosListState list = ref.watch(recorridosListProvider);
    final List<PendingRecorrido> pendientes = ref.watch(outboxProvider);

    // Búsqueda client-side (RF-02.7) sobre lo cargado.
    final String q = list.busqueda.trim().toLowerCase();
    final List<Recorrido> filtrados = q.isEmpty
        ? list.items
        : list.items
            .where((Recorrido r) => _matcher(r).contains(q))
            .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recorridos'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar',
            icon: list.isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: list.isRefreshing
                ? null
                : () =>
                    ref.read(recorridosListProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/recorridos/nuevo');
          // Al volver (creado / encolado) recargamos para reflejar cambios.
          ref.read(recorridosListProvider.notifier).recargarTrasCambio();
        },
        icon: const Icon(Icons.add_road_rounded),
        label: const Text('Nuevo'),
      ),
      body: Column(
        children: <Widget>[
          // ----- Banner del outbox (Fase 2.5) -----
          if (pendientes.isNotEmpty)
            _OutboxBanner(
              cantidad: pendientes.length,
              sincronizando: list.isSyncing,
              onRetry: () =>
                  ref.read(recorridosListProvider.notifier).refresh(),
            ),

          // ----- Filtros (RF-02.7) -----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: _FiltroVehiculoDropdown(
                    value: list.filtroVehiculoId,
                    onChanged: (int? id) => ref
                        .read(recorridosListProvider.notifier)
                        .setFiltroVehiculo(id),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: TextField(
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Matrícula o chofer',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (String v) =>
                        ref.read(recorridosListProvider.notifier).setBusqueda(v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ----- Error (con datos conservados) -----
          if (list.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FlowBanner(
                message: list.error!.userMessage,
                kind: FlowBannerKind.warning,
                onDismiss: () {},
              ),
            ),

          // ----- Contenido -----
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(recorridosListProvider.notifier).refresh(),
              child: list.primeraCargaSinDatos
                  ? const Center(child: CircularProgressIndicator())
                  : (pendientes.isEmpty && filtrados.isEmpty && list.error != null)
                      ? _ErrorRetry(
                          mensaje: list.error!.userMessage,
                          onRetry: () => ref
                              .read(recorridosListProvider.notifier)
                              .refresh(),
                        )
                      : (pendientes.isEmpty && filtrados.isEmpty)
                          ? ListView(
                              children: const <Widget>[
                                SizedBox(height: 80),
                                Icon(Icons.route_rounded,
                                    size: 56, color: Colors.grey),
                                SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    'Aún no hay recorridos registrados.\nPulsa «Nuevo» para registrar el primero.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            )
                          : NotificationListener<ScrollNotification>(
                              onNotification: (ScrollNotification sn) {
                                // Paginación infinita: cerca del fondo → siguiente página.
                                if (sn.metrics.pixels >=
                                        sn.metrics.maxScrollExtent - 200 &&
                                    list.hasNext &&
                                    !list.isLoadingMore &&
                                    !list.isRefreshing) {
                                  ref
                                      .read(recorridosListProvider.notifier)
                                      .loadMore();
                                }
                                return false;
                              },
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 96),
                                itemCount: pendientes.length +
                                    filtrados.length +
                                    (list.isLoadingMore ? 1 : 0),
                                itemBuilder: (BuildContext context, int i) {
                                  if (i < pendientes.length) {
                                    return _PendingTile(
                                      pending: pendientes[i],
                                      onDiscard: () => ref
                                          .read(outboxProvider.notifier)
                                          .discard(pendientes[i].localId),
                                    );
                                  }
                                  final int j = i - pendientes.length;
                                  if (j < filtrados.length) {
                                    final Recorrido r = filtrados[j];
                                    return _RecorridoTile(
                                      recorrido: r,
                                      onOpen: () async {
                                        await context.push('/recorridos/${r.id}');
                                        ref
                                            .read(recorridosListProvider.notifier)
                                            .recargarTrasCambio();
                                      },
                                    );
                                  }
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child:
                                            CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ),
        ],
      ),
    );
  }

  static String _matcher(Recorrido r) {
    final String matricula = r.vehiculo?.matricula ?? '';
    final String chofer = r.chofer?.nombreCompleto ?? '';
    return '$matricula $chofer ${r.fecha.toIso8601String()}';
  }
}

// ---------------------------------------------------------------------------
// Banner de pendientes (outbox)
// ---------------------------------------------------------------------------

class _OutboxBanner extends StatelessWidget {
  const _OutboxBanner({
    required this.cantidad,
    required this.sincronizando,
    required this.onRetry,
  });

  final int cantidad;
  final bool sincronizando;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            sincronizando ? Icons.sync_rounded : Icons.cloud_upload_outlined,
            size: 20,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sincronizando
                  ? 'Sincronizando recorridos pendientes…'
                  : '$cantidad recorrido${cantidad == 1 ? '' : 's'} pendiente${cantidad == 1 ? '' : 's'} de sync (guardado${cantidad == 1 ? '' : 's'} en el dispositivo)',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onTertiaryContainer),
            ),
          ),
          if (!sincronizando)
            TextButton(
              onPressed: onRetry,
              child: const Text('Sincronizar'),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filtro por vehículo
// ---------------------------------------------------------------------------

class _FiltroVehiculoDropdown extends ConsumerWidget {
  const _FiltroVehiculoDropdown({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Los vehículos del filtro usan la misma fuente que el formulario
    // (FlotaRepository, memoizada en sesión).
    final AsyncValue<List<Vehiculo>> vehiculos =
        ref.watch(vehiculosFiltroProvider);

    return vehiculos.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (Object _, StackTrace __) => DropdownButtonFormField<int>(
        value: value,
        isDense: true,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          labelText: 'Vehículo',
        ),
        items: const <DropdownMenuItem<int>>[],
        onChanged: onChanged,
      ),
      data: (List<Vehiculo> items) => DropdownButtonFormField<int>(
        value: value,
        isDense: true,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          labelText: 'Vehículo',
        ),
        hint: const Text('Todos'),
        items: <DropdownMenuItem<int>>[
          const DropdownMenuItem<int>(value: null, child: Text('Todos')),
          ...items
              .where((Vehiculo v) => v.activo)
              .map(
                (Vehiculo v) => DropdownMenuItem<int>(
                  value: v.id,
                  child: Text(v.etiqueta, overflow: TextOverflow.ellipsis),
                ),
              ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// Carga perezosa de vehículos para el filtro (memoizada en FlotaRepository).
final FutureProvider<List<Vehiculo>> vehiculosFiltroProvider =
    FutureProvider<List<Vehiculo>>((Ref ref) async {
  return ref.watch(flotaRepoProvider).obtenerVehiculos();
});

// ---------------------------------------------------------------------------
// Tiles
// ---------------------------------------------------------------------------

class _RecorridoTile extends StatelessWidget {
  const _RecorridoTile({required this.recorrido, required this.onOpen});

  final Recorrido recorrido;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onOpen,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: const Icon(Icons.route_rounded),
        ),
        title: Text(
          '${recorrido.vehiculo?.matricula ?? 'Vehículo'} · '
          '${_kmFmt.format(recorrido.kilometros)} km',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy').format(recorrido.fecha)} · '
          '${recorrido.chofer?.nombreCompleto ?? 'Sin chofer'}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (recorrido.tieneAbastecimiento)
              Tooltip(
                message: 'Con abastecimiento '
                    '(${_decFmt.format(recorrido.litrosAbastecidos ?? 0)} L)',
                child: Icon(
                  Icons.local_gas_station_rounded,
                  size: 18,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.pending, required this.onDiscard});

  final PendingRecorrido pending;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.tertiaryContainer.withOpacity(0.45),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Icon(Icons.schedule_rounded, color: theme.colorScheme.tertiary),
        title: Text(
          '${pending.input.kilometros} km · pendiente de sync',
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy').format(pending.input.fecha)} · '
          'se enviará automáticamente al recuperar conexión',
          style: theme.textTheme.bodySmall,
        ),
        trailing: IconButton(
          tooltip: 'Descartar borrador',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: onDiscard,
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.mensaje, required this.onRetry});

  final String mensaje;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
