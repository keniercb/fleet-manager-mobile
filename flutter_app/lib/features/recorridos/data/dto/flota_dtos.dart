/// DTOs del módulo de flota usados por RF-02.
///
/// Contratos textuales de `api-docs.json` (subconjunto consumido):
///   VehiculoResponse, ChoferResponse, TarjetaCombustibleResponse,
///   UserAuditResponse, CurrencyResponse y las páginas
///   PageVehiculoResponse / PageChoferResponse / PageTarjetaCombustibleResponse.
///
/// Nota ADR-02: escritos a mano para compilar sin `build_runner`, con
/// parsers tolerantes (los int64 pueden llegar como num/string).
import '../../../domain/entities/flota.dart';

class VehiculoDto {
  const VehiculoDto({
    required this.id,
    required this.matricula,
    required this.odometro,
    required this.activo,
    this.modelo,
    this.marcaNombre,
    this.tipoVehiculoNombre,
    this.tipoCombustibleNombre,
    this.combustible,
    this.indiceConsumo,
    this.chofer,
  });

  final int id;
  final String matricula;
  final int odometro;
  final bool activo;
  final String? modelo;
  final String? marcaNombre;
  final String? tipoVehiculoNombre;
  final String? tipoCombustibleNombre;
  final double? combustible;
  final double? indiceConsumo;
  final ChoferDto? chofer;

  factory VehiculoDto.fromJson(Map<String, dynamic> json) => VehiculoDto(
        id: _toInt(json['id']),
        matricula: json['matricula'] as String? ?? '',
        odometro: _toInt(json['odometro']),
        activo: json['activo'] as bool? ?? true,
        modelo: json['modelo'] as String?,
        marcaNombre: _nombre(json['marca']),
        tipoVehiculoNombre: _nombre(json['tipoVehiculo']),
        tipoCombustibleNombre: _denominacion(json['tipoCombustible']),
        combustible: _toDouble(json['combustible']),
        indiceConsumo: _toDouble(json['indiceConsumo']),
        chofer: json['chofer'] is Map
            ? ChoferDto.fromJson(
                Map<String, dynamic>.from(json['chofer'] as Map))
            : null,
      );

  Vehiculo toDomain() => Vehiculo(
        id: id,
        matricula: matricula,
        odometro: odometro,
        activo: activo,
        modelo: modelo,
        marcaNombre: marcaNombre,
        tipoVehiculoNombre: tipoVehiculoNombre,
        tipoCombustibleNombre: tipoCombustibleNombre,
        combustible: combustible,
        indiceConsumo: indiceConsumo,
        chofer: chofer?.toDomain(),
      );
}

class ChoferDto {
  const ChoferDto({
    required this.id,
    required this.nombre,
    required this.apellidos,
    required this.activo,
    this.numeroLicencia,
  });

  final int id;
  final String nombre;
  final String apellidos;
  final String? numeroLicencia;
  final bool activo;

  factory ChoferDto.fromJson(Map<String, dynamic> json) => ChoferDto(
        id: _toInt(json['id']),
        nombre: json['nombre'] as String? ?? '',
        apellidos: json['apellidos'] as String? ?? '',
        numeroLicencia: json['numeroLicencia'] as String?,
        activo: json['activo'] as bool? ?? true,
      );

  Chofer toDomain() => Chofer(
        id: id,
        nombre: nombre,
        apellidos: apellidos,
        numeroLicencia: numeroLicencia,
        activo: activo,
      );
}

class TarjetaCombustibleDto {
  const TarjetaCombustibleDto({
    required this.id,
    required this.numero,
    required this.saldo,
    required this.activo,
    this.isoCode,
  });

  final int id;
  final String numero;
  final double saldo;
  final String? isoCode;
  final bool activo;

  factory TarjetaCombustibleDto.fromJson(Map<String, dynamic> json) =>
      TarjetaCombustibleDto(
        id: _toInt(json['id']),
        numero: json['numero'] as String? ?? '',
        saldo: _toDouble(json['saldo']) ?? 0,
        isoCode: json['currency'] is Map
            ? (json['currency'] as Map)['isoCode'] as String?
            : null,
        activo: json['activo'] as bool? ?? true,
      );

  TarjetaCombustible toDomain() => TarjetaCombustible(
        id: id,
        numero: numero,
        saldo: saldo,
        isoCode: isoCode,
        activo: activo,
      );
}

// ---------------------------------------------------------------------------
// helpers tolerantes (idénticos a auth_dtos.dart)
// ---------------------------------------------------------------------------

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double? _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String? _nombre(Object? nested) {
  if (nested is Map && nested['nombre'] is String) {
    return nested['nombre'] as String;
  }
  return null;
}

/// `TipoCombustibleResponse` usa `denominacion` en vez de `nombre`.
String? _denominacion(Object? nested) {
  if (nested is Map) {
    final Object? v = nested['denominacion'] ?? nested['nombre'];
    if (v is String) return v;
  }
  return null;
}
