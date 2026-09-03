/// Contrato del repositorio de recorridos (RF-02.2 / Fase 2.2 del plan).
///
/// Capa dominio: sólo abstracciones. La implementación (Dio) vive en
/// `data/repositories/recorridos_repository_impl.dart`.
///
/// Endpoints backend (api-docs.json → tag "Trips"):
///   GET    /api/recorridos?page&perPage&sort&sortOrder   → PageRecorridoResponse
///   GET    /api/recorridos/vehiculo/{vehiculoId}?from&to&page&perPage
///   GET    /api/recorridos/{id}                          → RecorridoResponse
///   POST   /api/recorridos        (RecorridoRequest)     → RecorridoResponse
///   PUT    /api/recorridos/{id}   (RecorridoRequest)     → RecorridoResponse
///   DELETE /api/recorridos/{id}   → 200 con cuerpo vacío (R6)
///
/// Errores: implementaciones lanzan `Failure` (ADR-06); los use cases los
/// capturan y devuelven `Result`.
import '../entities/page.dart';
import '../entities/recorrido.dart';
import '../../../../core/utils/page_params.dart';

abstract class RecorridosRepository {
  /// RF-02.4 — listado global paginado (orden fecha DESC desde el cliente:
  /// `sort=fecha&sortOrder=DESC`).
  Future<PageResult<Recorrido>> listar(PageParams params);

  /// RF-02.7 — historial filtrable por vehículo (opcionalmente por rango de
  /// fechas, `from`/`to` formato `yyyy-MM-dd`).
  Future<PageResult<Recorrido>> listarPorVehiculo(
    int vehiculoId, {
    DateTime? desde,
    DateTime? hasta,
    PageParams params = const PageParams(sort: 'fecha', sortOrder: 'DESC'),
  });

  /// RF-02.5 — detalle completo con calculados y auditoría.
  Future<Recorrido> obtener(int id);

  /// RF-02.1 — registro. En éxito devuelve el recorrido persistido por el
  /// servidor (con calculados).
  Future<Recorrido> crear(RecorridoInput input);

  /// RF-02.6 — edición.
  Future<Recorrido> actualizar(int id, RecorridoInput input);

  /// RF-02.6 — borrado (lógico en el backend vía `activo`). DELETE responde
  /// 200 con cuerpo vacío → tratar como éxito (R6).
  Future<void> eliminar(int id);
}
