/// Caso de uso: eliminar un recorrido (RF-02.6).
///
/// El backend hace borrado lógico (`activo=false`) y responde 200 con
/// cuerpo vacío (R6 → éxito aunque no venga cuerpo). Sólo roles de gestión
/// alcanzan esta operación: la UI oculta la acción según `UserCapabilities`
/// (RF-01.3) y el backend vuelve a validar (403 → `ForbiddenFailure`).
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../repositories/recorridos_repository.dart';

class EliminarRecorridoUseCase {
  EliminarRecorridoUseCase(this._repository);

  final RecorridosRepository _repository;

  Future<Result<void>> call(int id) async {
    try {
      await _repository.eliminar(id);
      return const Result.success<void>(null);
    } on Failure catch (failure) {
      return Result.failure<void>(failure);
    }
  }
}
