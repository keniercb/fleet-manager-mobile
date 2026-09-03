/// Cliente API de flota para los catálogos del formulario RF-02.
///
/// Endpoints (api-docs.json):
///   GET /api/vehiculos?filter&page&perPage          → PageVehiculoResponse
///   GET /api/choferes?filter&page&perPage           → PageChoferResponse
///   GET /api/tarjetas-combustible?filter&page&perPage
///                                                   → PageTarjetaCombustibleResponse
///
/// Para los selectores se pide una página amplia (`perPage: 50`); la
/// búsqueda fina con `filter` llega con RF-03.
import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../dto/flota_dtos.dart';

class FlotaApi {
  FlotaApi(this._dio);

  final Dio _dio;

  static const int _perPageSelector = 50;

  Future<List<VehiculoDto>> obtenerVehiculos({String? filter}) async {
    final Response<Map<String, dynamic>> res =
        await _dio.get<Map<String, dynamic>>(
      AppConfig.vehiculosPath,
      queryParameters: <String, String>{
        'page': '0',
        'perPage': '$_perPageSelector',
        if (filter != null && filter.isNotEmpty) 'filter': filter,
      },
    );
    return _items(res)
        .map((Map<String, dynamic> json) => VehiculoDto.fromJson(json))
        .toList();
  }

  Future<List<ChoferDto>> obtenerChoferes({String? filter}) async {
    final Response<Map<String, dynamic>> res =
        await _dio.get<Map<String, dynamic>>(
      AppConfig.choferesPath,
      queryParameters: <String, String>{
        'page': '0',
        'perPage': '$_perPageSelector',
        if (filter != null && filter.isNotEmpty) 'filter': filter,
      },
    );
    return _items(res)
        .map((Map<String, dynamic> json) => ChoferDto.fromJson(json))
        .toList();
  }

  Future<List<TarjetaCombustibleDto>> obtenerTarjetas({String? filter}) async {
    final Response<Map<String, dynamic>> res =
        await _dio.get<Map<String, dynamic>>(
      AppConfig.tarjetasPath,
      queryParameters: <String, String>{
        'page': '0',
        'perPage': '$_perPageSelector',
        if (filter != null && filter.isNotEmpty) 'filter': filter,
      },
    );
    return _items(res)
        .map((Map<String, dynamic> json) => TarjetaCombustibleDto.fromJson(json))
        .toList();
  }

  static List<Map<String, dynamic>> _items(Response<Map<String, dynamic>> res) {
    final Map<String, dynamic> body = res.data ?? <String, dynamic>{};
    return (body['content'] as List? ?? <Object?>[])
        .whereType<Map>()
        .map((Map e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
