/// Implementación de [FlotaRepository] sobre Dio (sólo lectura para RF-02).
///
/// Los catálogos se piden al backend y se memoizan en memoria de sesión
/// (sustituto mínimo de la cache Drift TTL 24h de la Fase 2.1). La
/// invalidación ocurre al reabrir el formulario tras un cambio de flota —
/// para RF-02 es suficiente; Fase 3 introducirá refresh explícito.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart' show dioProvider;
import '../../domain/entities/flota.dart';
import '../../domain/repositories/flota_repository.dart';
import '../api/flota_api.dart';
import '../dto/flota_dtos.dart';

class FlotaRepositoryImpl implements FlotaRepository {
  FlotaRepositoryImpl({required FlotaApi api}) : _api = api;

  final FlotaApi _api;

  // Memoización de sesión (no persistente).
  List<Vehiculo>? _vehiculosCache;
  List<Chofer>? _choferesCache;
  List<TarjetaCombustible>? _tarjetasCache;

  @override
  Future<List<Vehiculo>> obtenerVehiculos({String? filter}) async {
    if (_vehiculosCache != null) return _vehiculosCache!;
    try {
      final List<VehiculoDto> dtos = await _api.obtenerVehiculos(filter: filter);
      _vehiculosCache = dtos.map((VehiculoDto d) => d.toDomain()).toList();
      return _vehiculosCache!;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<List<Chofer>> obtenerChoferes({String? filter}) async {
    if (_choferesCache != null) return _choferesCache!;
    try {
      final List<ChoferDto> dtos = await _api.obtenerChoferes(filter: filter);
      _choferesCache = dtos.map((ChoferDto d) => d.toDomain()).toList();
      return _choferesCache!;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<List<TarjetaCombustible>> obtenerTarjetas({String? filter}) async {
    if (_tarjetasCache != null) return _tarjetasCache!;
    try {
      final List<TarjetaCombustibleDto> dtos =
          await _api.obtenerTarjetas(filter: filter);
      _tarjetasCache = dtos.map((TarjetaCombustibleDto d) => d.toDomain()).toList();
      return _tarjetasCache!;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// Invalida la memoización (p. ej. tras sincronizar el outbox y querer
  /// odómetros frescos del servidor).
  void invalidate() {
    _vehiculosCache = null;
    _choferesCache = null;
    _tarjetasCache = null;
  }
}

final Provider<FlotaRepositoryImpl> flotaRepositoryProvider =
    Provider<FlotaRepositoryImpl>((Ref ref) {
  return FlotaRepositoryImpl(api: FlotaApi(ref.watch(dioProvider)));
});
