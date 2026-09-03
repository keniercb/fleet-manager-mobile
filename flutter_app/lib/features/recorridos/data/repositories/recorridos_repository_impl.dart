/// Implementación de [RecorridosRepository] sobre Dio.
///
/// Traduce `DioException` → `Failure` (ADR-06). Sin caché local todavía:
/// la lista siempre refleja el servidor (fuente de verdad del odómetro,
/// R7); la cache Drift + outbox persistente llegan en Fase 6.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart' show dioProvider;
import '../../../../core/utils/page_params.dart';
import '../../domain/entities/page.dart';
import '../../domain/entities/recorrido.dart';
import '../../domain/repositories/recorridos_repository.dart';
import '../api/recorridos_api.dart';

class RecorridosRepositoryImpl implements RecorridosRepository {
  RecorridosRepositoryImpl({required RecorridosApi api}) : _api = api;

  final RecorridosApi _api;

  @override
  Future<PageResult<Recorrido>> listar(PageParams params) async {
    try {
      return await _api.listar(params);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<PageResult<Recorrido>> listarPorVehiculo(
    int vehiculoId, {
    DateTime? desde,
    DateTime? hasta,
    PageParams params = const PageParams(sort: 'fecha', sortOrder: 'DESC'),
  }) async {
    try {
      return await _api.listarPorVehiculo(
        vehiculoId,
        desde: desde,
        hasta: hasta,
        params: params,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<Recorrido> obtener(int id) async {
    try {
      return await _api.obtener(id);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<Recorrido> crear(RecorridoInput input) async {
    try {
      return await _api.crear(input);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<Recorrido> actualizar(int id, RecorridoInput input) async {
    try {
      return await _api.actualizar(id, input);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<void> eliminar(int id) async {
    try {
      // R6: DELETE responde 200 con cuerpo vacío — éxito sin cuerpo.
      await _api.eliminar(id);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}

final Provider<RecorridosRepository> recorridosRepositoryProvider =
    Provider<RecorridosRepository>((Ref ref) {
  return RecorridosRepositoryImpl(
    api: RecorridosApi(ref.watch(dioProvider)),
  );
});
