/// Controlador del detalle de recorrido (RF-02.5 — datos calculados y
/// auditoría) y su eliminación (RF-02.6).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/recorrido.dart';
import '../../recorridos_providers.dart'
    show eliminarRecorridoUseCaseProvider, obtenerRecorridoUseCaseProvider;
import '../../domain/usecases/eliminar_recorrido.dart';
import '../../domain/usecases/obtener_recorrido.dart';
import 'recorridos_list_controller.dart';

sealed class RecorridoDetailState {
  const RecorridoDetailState();
}

class RecorridoDetailLoading extends RecorridoDetailState {
  const RecorridoDetailLoading();
}

class RecorridoDetailLoaded extends RecorridoDetailState {
  const RecorridoDetailLoaded({required this.recorrido, this.eliminando = false});
  final Recorrido recorrido;
  final bool eliminando;
}

class RecorridoDetailError extends RecorridoDetailState {
  const RecorridoDetailError(this.failure);
  final Failure failure;
}

/// family por id de recorrido: `ref.watch(recorridoDetailProvider(id))`.
class RecorridoDetailController
    extends FamilyNotifier<RecorridoDetailState, int> {
  late final ObtenerRecorridoUseCase _obtener =
      ref.read(obtenerRecorridoUseCaseProvider);
  late final EliminarRecorridoUseCase _eliminar =
      ref.read(eliminarRecorridoUseCaseProvider);

  @override
  RecorridoDetailState build(int arg) {
    Future<void>.microtask(cargar);
    return const RecorridoDetailLoading();
  }

  Future<void> cargar() async {
    state = const RecorridoDetailLoading();
    final Result<Recorrido> result = await _obtener(arg);
    result.when(
      success: (Recorrido recorrido) =>
          state = RecorridoDetailLoaded(recorrido: recorrido),
      failure: (Failure failure) => state = RecorridoDetailError(failure),
    );
  }

  /// RF-02.6 — eliminación con confirmación previa en la UI.
  /// Devuelve el `Failure` si falló (la UI muestra el banner) o `null`.
  Future<Failure?> eliminar() async {
    final RecorridoDetailState current = state;
    if (current is! RecorridoDetailLoaded) return const UnknownFailure();
    state = RecorridoDetailLoaded(
      recorrido: current.recorrido,
      eliminando: true,
    );
    final Result<void> result = await _eliminar(arg);
    final Failure? failure = result.failureOrNull;
    if (failure != null) {
      state = RecorridoDetailLoaded(
        recorrido: current.recorrido,
        eliminando: false,
      );
      return failure;
    }
    // La lista debe reflejar el borrado al volver.
    ref.read(recorridosListProvider.notifier).recargarTrasCambio();
    return null;
  }
}

final NotifierProviderFamily<RecorridoDetailController, RecorridoDetailState,
        int> recorridoDetailProvider =
    NotifierProvider.family<RecorridoDetailController, RecorridoDetailState,
        int>(RecorridoDetailController.new);
