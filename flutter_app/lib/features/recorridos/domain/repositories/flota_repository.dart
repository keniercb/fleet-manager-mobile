/// Contrato del repositorio de flota para RF-02 (sólo lectura).
///
/// El formulario de recorridos (RF-02.1) necesita los catálogos operativos:
///   GET /api/vehiculos?filter&page&perPage         → PageVehiculoResponse
///   GET /api/choferes?filter&page&perPage          → PageChoferResponse
///   GET /api/tarjetas-combustible?filter&page&perPage
///                                                  → PageTarjetaCombustibleResponse
///
/// Fase 2.1 del plan contempla cache local (Drift TTL 24h); la
/// implementación actual es remota + memoria de sesión y el punto único de
/// sustitución es `FlotaRepositoryImpl` (los use cases no cambian).
import '../../../../core/utils/page_params.dart';
import '../entities/flota.dart';

abstract class FlotaRepository {
  /// Vehículos activos de la empresa del usuario (para el selector).
  Future<List<Vehiculo>> obtenerVehiculos({String? filter});

  /// Choferes activos de la empresa del usuario (para el selector).
  Future<List<Chofer>> obtenerChoferes({String? filter});

  /// Tarjetas de combustible con saldo visible (RF-02.2).
  Future<List<TarjetaCombustible>> obtenerTarjetas({String? filter});
}
