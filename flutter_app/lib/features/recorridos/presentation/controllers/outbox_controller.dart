/// Outbox + SyncManager v1 (Fase 2.5) — RF-07.1 groundwork.
///
/// Cola FIFO de recorridos creados sin red. La sincronización se dispara:
///   1. Automática al cargar/refrescar la lista si hay pendientes
///      (Gate F2: «recuperar conexión → sync»).
///   2. Manual con el botón «Reintentar sincronización» del banner.
///
/// El reenvío usa el mismo [CrearRecorridoUseCase] que el formulario: el
/// servidor no distingue una creación sincronizada de una en línea.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/recorrido.dart';
import '../../data/local/outbox_store.dart';
import '../../recorridos_providers.dart'
    show crearRecorridoUseCaseProvider;

class OutboxController extends Notifier<List<PendingRecorrido>> {
  late final OutboxStore _store = ref.read(outboxStoreProvider);
  late final CrearRecorridoUseCase _crear = ref.read(crearRecorridoUseCaseProvider);

  bool _syncing = false;

  @override
  List<PendingRecorrido> build() {
    // Carga la cola persistida al arrancar (sobrevive reinicios de la app).
    Future<void>.microtask(_cargar);
    return const <PendingRecorrido>[];
  }

  Future<void> _cargar() async {
    state = await _store.load();
  }

  /// Encola un input que no pudo enviarse por red y devuelve su `localId`.
  Future<String> enqueue(RecorridoInput input) async {
    final PendingRecorrido pending = PendingRecorrido(
      localId:
          'local-${DateTime.now().millisecondsSinceEpoch}-${state.length}',
      input: input,
      createdAt: DateTime.now(),
    );
    final List<PendingRecorrido> next = <PendingRecorrido>[...state, pending];
    state = next;
    await _store.save(next);
    return pending.localId;
  }

  /// Descarta un draft (el usuario lo eliminó antes de sincronizar).
  Future<void> discard(String localId) async {
    final List<PendingRecorrido> next =
        state.where((PendingRecorrido p) => p.localId != localId).toList();
    state = next;
    await _store.save(next);
  }

  /// Edición local de un draft aún no sincronizado.
  Future<void> updateDraft(String localId, RecorridoInput input) async {
    final List<PendingRecorrido> next = state
        .map((PendingRecorrido p) =>
            p.localId == localId ? p.copyWith(input: input) : p)
        .toList();
    state = next;
    await _store.save(next);
  }

  /// Reenvía la cola en FIFO. Devuelve cuántos se sincronizaron; se detiene
  /// ante el primer fallo (normalmente red) conservando el resto del orden.
  Future<int> syncAll() async {
    if (_syncing) return 0;
    if (state.isEmpty) return 0;
    _syncing = true;
    int sincronizados = 0;
    try {
      while (state.isNotEmpty) {
        final PendingRecorrido primero = state.first;
        final Result<Recorrido> result = await _crear(primero.input);
        final Failure? failure = result.failureOrNull;
        if (failure != null) {
          // Registra el intento y detiene (v1: sin backoff — llega con RNF-04).
          final List<PendingRecorrido> next = <PendingRecorrido>[
            primero.copyWith(
              attempts: primero.attempts + 1,
              lastError: failure.userMessage,
            ),
            ...state.sublist(1),
          ];
          state = next;
          await _store.save(next);
          break;
        }
        final List<PendingRecorrido> next = <PendingRecorrido>[...state]
          ..removeAt(0);
        state = next;
        await _store.save(next);
        sincronizados++;
      }
    } finally {
      _syncing = false;
    }
    return sincronizados;
  }
}

final NotifierProvider<OutboxController, List<PendingRecorrido>>
    outboxProvider =
    NotifierProvider<OutboxController, List<PendingRecorrido>>(
  OutboxController.new,
);
