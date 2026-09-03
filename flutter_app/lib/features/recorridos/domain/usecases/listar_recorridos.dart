/// Caso de uso: listar recorridos con paginación (RF-02.4 / RF-02.7).
///
/// Unifica los dos endpoints del backend:
///   - sin `vehiculoId` → GET /api/recorridos (global)
///   - con `vehiculoId` → GET /api/recorridos/vehiculo/{id} (+ rango opcional)
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/page_params.dart';
import '../entities/page.dart';
import '../entities/recorrido.dart';
import '../repositories/recorridos_repository.dart';

class ListarRecorridosUseCase {
  ListarRecorridosUseCase(this._repository);

  final RecorridosRepository _repository;

  Future<Result<PageResult<Recorrido>>> call({
    int? vehiculoId,
    DateTime? desde,
    DateTime? hasta,
    PageParams params = const PageParams(sort: 'fecha', sortOrder: 'DESC'),
  }) async {
    try {
      final PageResult<Recorrido> page = (vehiculoId == null)
          ? await _repository.listar(params)
          : await _repository.listarPorVehiculo(
              vehiculoId,
              desde: desde,
              hasta: hasta,
              params: params,
            );
      return Result.success<PageResult<Recorrido>>(page);
    } on Failure catch (failure) {
      return Result.failure<PageResult<Recorrido>>(failure);
    }
  }
}
