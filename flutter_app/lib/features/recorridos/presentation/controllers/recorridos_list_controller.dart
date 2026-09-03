/// Controlador de la lista de recorridos (RF-02.4 / RF-02.7).
///
/// Estados de carga desacoplados:
///   - `isLoading`    : primera carga (sin datos aún).
///   - `isRefreshing` : pull-to-refresh / reintentar (conserva la lista).
///   - `isLoadingMore`: paginación infinita (conserva la lista).
///
/// Orden pedido al servidor: `sort=fecha&sortOrder=DESC` (RF-02.4).
/// La búsqueda rápida por matrícula/chofer (RF-02.7) es client-side sobre
/// lo cargado — los ítems pendientes del outbox se muestran primero.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/page_params.dart';
import '../../domain/entities/page.dart';
import '../../domain/entities/recorrido.dart';
import '../../domain/usecases/listar_recorridos.dart';
import '../../recorridos_providers.dart' show listarRecorridosUseCaseProvider;
import 'outbox_controller.dart';

/// Página por defecto de la lista infinita.
const int perPageLista = 10;

class RecorridosListState {
  const RecorridosListState({
    this.items = const <Recorrido>[],
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isSyncing = false,
    this.error,
    this.filtroVehiculoId,
    this.busqueda = '',
    this.totalElements = 0,
    this.hasNext = false,
  });

  final List<Recorrido> items;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isSyncing;

  /// Último `Failure`; la UI muestra el estado de error con Reintentar
  /// pero conserva los ítems ya cargados y los pendientes del outbox.
  final Failure? error;
  final int? filtroVehiculoId;
  final String busqueda;
  final int totalElements;
  final bool hasNext;

  bool get primeraCargaSinDatos => isLoading && items.isEmpty;

  RecorridosListState copyWith({
    List<Recorrido>? items,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isSyncing,
    Failure? error,
    bool clearError = false,
    int? filtroVehiculoId,
    bool clearFiltro = false,
    String? busqueda,
    int? totalElements,
    bool? hasNext,
  }) {
    return RecorridosListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSyncing: isSyncing ?? this.isSyncing,
      error: clearError ? null : (error ?? this.error),
      filtroVehiculoId: clearFiltro ? null : (filtroVehiculoId ?? this.filtroVehiculoId),
      busqueda: busqueda ?? this.busqueda,
      totalElements: totalElements ?? this.totalElements,
      hasNext: hasNext ?? this.hasNext,
    );
  }
}

class RecorridosListController extends Notifier<RecorridosListState> {
  late final ListarRecorridosUseCase _listar =
      ref.read(listarRecorridosUseCaseProvider);

  PageParams _params = const PageParams(
    perPage: perPageLista,
    sort: 'fecha',
    sortOrder: 'DESC',
  );

  @override
  RecorridosListState build() {
    // Primera carga automática al entrar al módulo.
    Future<void>.microtask(refresh);
    return const RecorridosListState(isLoading: true);
  }

  /// Pull-to-refresh / reintentar / primer load: intenta sincronizar el
  /// outbox (Gate F2) y recarga la página 0 del servidor.
  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);

    // 1) Si hay pendientes → sync FIFO; en éxito la página 0 reflejará los
    //    recorridos ya persistidos por el servidor.
    if (ref.read(outboxProvider).isNotEmpty) {
      state = state.copyWith(isSyncing: true);
      await ref.read(outboxProvider.notifier).syncAll();
      state = state.copyWith(isSyncing: false);
    }

    // 2) Página 0 con el filtro vigente.
    _params = _params.first();
    final result = await _listar(
      vehiculoId: state.filtroVehiculoId,
      params: _params,
    );
    result.when(
      success: (PageResult<Recorrido> page) {
        state = state.copyWith(
          items: page.content,
          totalElements: page.totalElements,
          hasNext: page.hasNext,
          isRefreshing: false,
          isLoading: false,
          clearError: true,
        );
      },
      failure: (Failure failure) {
        state = state.copyWith(
          error: failure,
          isRefreshing: false,
          isLoading: false,
        );
      },
    );
  }

  /// Paginación infinita: siguiente página y append (RF-02.4).
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasNext || state.isRefreshing) return;
    state = state.copyWith(isLoadingMore: true);
    _params = _params.next();
    final result = await _listar(
      vehiculoId: state.filtroVehiculoId,
      params: _params,
    );
    result.when(
      success: (PageResult<Recorrido> page) {
        final Set<int> idsExistentes =
            state.items.map((Recorrido r) => r.id).toSet();
        final List<Recorrido> nuevos = page.content
            .where((Recorrido r) => !idsExistentes.contains(r.id))
            .toList();
        state = state.copyWith(
          items: <Recorrido>[...state.items, ...nuevos],
          hasNext: page.hasNext,
          isLoadingMore: false,
        );
      },
      failure: (Failure failure) {
        state = state.copyWith(isLoadingMore: false, error: failure);
      },
    );
  }

  /// RF-02.7 — filtro por vehículo (recarga desde la página 0).
  Future<void> setFiltroVehiculo(int? vehiculoId) async {
    state = state.copyWith(
      filtroVehiculoId: vehiculoId,
      clearFiltro: vehiculoId == null,
    );
    await refresh();
  }

  /// RF-02.7 — búsqueda rápida por matrícula/chofer (client-side).
  void setBusqueda(String query) {
    state = state.copyWith(busqueda: query);
  }

  /// Después de crear/editar/eliminar en el formulario → recarga limpia.
  Future<void> recargarTrasCambio() => refresh();
}

final NotifierProvider<RecorridosListController, RecorridosListState>
    recorridosListProvider =
    NotifierProvider<RecorridosListController, RecorridosListState>(
  RecorridosListController.new,
);
