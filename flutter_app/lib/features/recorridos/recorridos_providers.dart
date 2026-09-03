/// Composition root del feature `recorridos` (RF-02) — mismos criterios que
/// `auth_providers.dart`: los use cases quedan libres de `data` y todo el
/// cableado vive aquí.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/repositories/flota_repository_impl.dart';
import 'data/repositories/recorridos_repository_impl.dart'
    show recorridosRepositoryProvider;
import 'domain/repositories/flota_repository.dart';
import 'domain/usecases/actualizar_recorrido.dart';
import 'domain/usecases/cargar_datos_formulario.dart';
import 'domain/usecases/crear_recorrido.dart';
import 'domain/usecases/eliminar_recorrido.dart';
import 'domain/usecases/listar_recorridos.dart';
import 'domain/usecases/obtener_recorrido.dart';

// Repositorios.
export 'data/repositories/flota_repository_impl.dart'
    show flotaRepositoryProvider;
export 'data/repositories/recorridos_repository_impl.dart'
    show recorridosRepositoryProvider;

/// [FlotaRepository] expuesto como su interfaz (los use cases no conocen
/// la implementación concreta ni su `invalidate()`).
final Provider<FlotaRepository> flotaRepoProvider =
    Provider<FlotaRepository>((Ref ref) => ref.watch(flotaRepositoryProvider));

// Use cases (RF-02).
final Provider<ListarRecorridosUseCase> listarRecorridosUseCaseProvider =
    Provider<ListarRecorridosUseCase>(
  (Ref ref) => ListarRecorridosUseCase(ref.watch(recorridosRepositoryProvider)),
);

final Provider<ObtenerRecorridoUseCase> obtenerRecorridoUseCaseProvider =
    Provider<ObtenerRecorridoUseCase>(
  (Ref ref) =>
      ObtenerRecorridoUseCase(ref.watch(recorridosRepositoryProvider)),
);

final Provider<CrearRecorridoUseCase> crearRecorridoUseCaseProvider =
    Provider<CrearRecorridoUseCase>(
  (Ref ref) => CrearRecorridoUseCase(ref.watch(recorridosRepositoryProvider)),
);

final Provider<ActualizarRecorridoUseCase> actualizarRecorridoUseCaseProvider =
    Provider<ActualizarRecorridoUseCase>(
  (Ref ref) =>
      ActualizarRecorridoUseCase(ref.watch(recorridosRepositoryProvider)),
);

final Provider<EliminarRecorridoUseCase> eliminarRecorridoUseCaseProvider =
    Provider<EliminarRecorridoUseCase>(
  (Ref ref) =>
      EliminarRecorridoUseCase(ref.watch(recorridosRepositoryProvider)),
);

final Provider<CargarDatosFormularioUseCase>
    cargarDatosFormularioUseCaseProvider =
    Provider<CargarDatosFormularioUseCase>(
  (Ref ref) => CargarDatosFormularioUseCase(ref.watch(flotaRepoProvider)),
);
