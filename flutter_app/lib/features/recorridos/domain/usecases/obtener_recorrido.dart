/// Caso de uso: obtener el detalle de un recorrido (RF-02.5).
///
/// Devuelve el `RecorridoResponse` completo del servidor, incluidos los
/// campos calculados (odómetro inicial, combustible inicial, consumo) y la
/// auditoría.
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../entities/recorrido.dart';
import '../repositories/recorridos_repository.dart';

class ObtenerRecorridoUseCase {
  ObtenerRecorridoUseCase(this._repository);

  final RecorridosRepository _repository;

  Future<Result<Recorrido>> call(int id) async {
    try {
      final Recorrido recorrido = await _repository.obtener(id);
      return Result.success<Recorrido>(recorrido);
    } on Failure catch (failure) {
      return Result.failure<Recorrido>(failure);
    }
  }
}
