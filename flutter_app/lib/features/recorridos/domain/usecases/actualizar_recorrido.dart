/// Caso de uso: editar un recorrido (RF-02.6).
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../entities/recorrido.dart';
import '../repositories/recorridos_repository.dart';

class ActualizarRecorridoUseCase {
  ActualizarRecorridoUseCase(this._repository);

  final RecorridosRepository _repository;

  Future<Result<Recorrido>> call(int id, RecorridoInput input) async {
    try {
      final Recorrido recorrido = await _repository.actualizar(id, input);
      return Result.success<Recorrido>(recorrido);
    } on Failure catch (failure) {
      return Result.failure<Recorrido>(failure);
    }
  }
}
