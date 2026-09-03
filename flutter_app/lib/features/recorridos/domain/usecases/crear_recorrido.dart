/// Caso de uso: registrar un recorrido (RF-02.1 / RF-02.2).
///
/// El repositorio envía el `RecorridoRequest` tal cual el contrato; las
/// validaciones de cliente (RF-02.3) corren antes, en el controlador del
/// formulario. Si no hay red, el llamador puede encolar en el outbox
/// (Fase 2.5) con el mismo [RecorridoInput].
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../entities/recorrido.dart';
import '../repositories/recorridos_repository.dart';

class CrearRecorridoUseCase {
  CrearRecorridoUseCase(this._repository);

  final RecorridosRepository _repository;

  Future<Result<Recorrido>> call(RecorridoInput input) async {
    try {
      final Recorrido recorrido = await _repository.crear(input);
      return Result.success<Recorrido>(recorrido);
    } on Failure catch (failure) {
      return Result.failure<Recorrido>(failure);
    }
  }
}
