/// Cliente API del módulo de recorridos (RF-02).
///
/// Endpoints (api-docs.json → tag "Trips"):
///   GET    /api/recorridos?page&perPage&sort&sortOrder      → PageRecorridoResponse
///   GET    /api/recorridos/vehiculo/{vehiculoId}            → PageRecorridoResponse
///   GET    /api/recorridos/{id}                             → RecorridoResponse
///   POST   /api/recorridos                                  → RecorridoResponse
///   PUT    /api/recorridos/{id}                             → RecorridoResponse
///   DELETE /api/recorridos/{id}                             → 200 (cuerpo vacío, R6)
///
/// Nota (R5): la convención de paginación vive en `PageParams.toQuery()`.
/// El orden por fecha DESC (RF-02.4) lo pide el cliente: `sort=fecha`.
import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/utils/page_params.dart';
import '../../../domain/entities/page.dart';
import '../../../domain/entities/recorrido.dart';
import '../dto/flota_dtos.dart';
import '../dto/recorrido_dtos.dart';

class RecorridosApi {
  RecorridosApi(this._dio);

  final Dio _dio;

  /// RF-02.4 — listado global.
  Future<PageResult<Recorrido>> listar(PageParams params) async {
    final Response<Map<String, dynamic>> res = await _dio.get<Map<String, dynamic>>(
      AppConfig.recorridosPath,
      queryParameters: params.toQuery(),
    );
    return parsePage(res, (Map<String, dynamic> json) {
      return RecorridoDto.fromJson(json).toDomain();
    });
  }

  /// RF-02.7 — listado por vehículo con rango opcional (`from`/`to`).
  Future<PageResult<Recorrido>> listarPorVehiculo(
    int vehiculoId, {
    DateTime? desde,
    DateTime? hasta,
    PageParams params = const PageParams(sort: 'fecha', sortOrder: 'DESC'),
  }) async {
    final Map<String, String> query = params.toQuery();
    if (desde != null) query['from'] = _isoDate(desde);
    if (hasta != null) query['to'] = _isoDate(hasta);
    final Response<Map<String, dynamic>> res =
        await _dio.get<Map<String, dynamic>>(
      '${AppConfig.recorridosPath}/vehiculo/$vehiculoId',
      queryParameters: query,
    );
    return parsePage(res, (Map<String, dynamic> json) {
      return RecorridoDto.fromJson(json).toDomain();
    });
  }

  /// RF-02.5 — detalle.
  Future<Recorrido> obtener(int id) async {
    final Response<Map<String, dynamic>> res =
        await _dio.get<Map<String, dynamic>>(
      '${AppConfig.recorridosPath}/$id',
    );
    return RecorridoDto.fromJson(res.data ?? <String, dynamic>{}).toDomain();
  }

  /// RF-02.1 — crear.
  Future<Recorrido> crear(RecorridoInput input) async {
    final Response<Map<String, dynamic>> res =
        await _dio.post<Map<String, dynamic>>(
      AppConfig.recorridosPath,
      data: input.toJson(),
    );
    return RecorridoDto.fromJson(res.data ?? <String, dynamic>{}).toDomain();
  }

  /// RF-02.6 — actualizar.
  Future<Recorrido> actualizar(int id, RecorridoInput input) async {
    final Response<Map<String, dynamic>> res =
        await _dio.put<Map<String, dynamic>>(
      '${AppConfig.recorridosPath}/$id',
      data: input.toJson(),
    );
    return RecorridoDto.fromJson(res.data ?? <String, dynamic>{}).toDomain();
  }

  /// RF-02.6 — eliminar (200 con cuerpo vacío → éxito, R6).
  Future<void> eliminar(int id) async {
    await _dio.delete<void>('${AppConfig.recorridosPath}/$id');
  }

  static String _isoDate(DateTime d) {
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
