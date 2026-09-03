/// DTOs del módulo de recorridos (RF-02).
///
/// Contratos textuales de `api-docs.json`:
///   RecorridoRequest  { vehiculoId, choferId?, fecha, kilometros,
///                       litrosAbastecidos?, numeroChip?, lugarAbastecimiento?,
///                       tarjetaCombustibleId?, importeAbastecido? }
///   RecorridoResponse { id, vehiculo, chofer, fecha, kilometros,
///                       odometroInicial, combustibleInicial, consumo,
///                       litrosAbastecidos, numeroChip, lugarAbastecimiento,
///                       tarjetaCombustible, importeAbastecido, activo,
///                       fechaCreacion, fechaActualizacion, creadoPor,
///                       modificadoPor }
///   PageRecorridoResponse { content[], totalElements, totalPages, number,
///                       size, first, last, empty }
///
/// Nota ADR-02: escritos a mano (sin build_runner); parsers tolerantes.
/// La petición la serializa `RecorridoInput.toJson()` (entidad de dominio).
import 'package:dio/dio.dart';

import '../../../domain/entities/page.dart';
import '../../../domain/entities/recorrido.dart';
import 'flota_dtos.dart';

class RecorridoDto {
  const RecorridoDto({required this.raw});

  final Map<String, dynamic> raw;

  factory RecorridoDto.fromJson(Map<String, dynamic> json) =>
      RecorridoDto(raw: json);

  Recorrido toDomain() => Recorrido(
        id: _toInt(raw['id']),
        fecha: _toDate(raw['fecha']) ?? DateTime.now(),
        kilometros: _toInt(raw['kilometros']),
        activo: raw['activo'] as bool? ?? true,
        vehiculo: raw['vehiculo'] is Map
            ? VehiculoDto.fromJson(
                    Map<String, dynamic>.from(raw['vehiculo'] as Map))
                .toDomain()
            : null,
        chofer: raw['chofer'] is Map
            ? ChoferDto.fromJson(
                    Map<String, dynamic>.from(raw['chofer'] as Map))
                .toDomain()
            : null,
        odometroInicial: raw['odometroInicial'] == null
            ? null
            : _toInt(raw['odometroInicial']),
        combustibleInicial: _toDouble(raw['combustibleInicial']),
        consumo: _toDouble(raw['consumo']),
        litrosAbastecidos: _toDouble(raw['litrosAbastecidos']),
        numeroChip: raw['numeroChip'] as String?,
        lugarAbastecimiento: raw['lugarAbastecimiento'] as String?,
        tarjeta: raw['tarjetaCombustible'] is Map
            ? TarjetaCombustibleDto.fromJson(
                    Map<String, dynamic>.from(raw['tarjetaCombustible'] as Map))
                .toDomain()
            : null,
        importeAbastecido: _toDouble(raw['importeAbastecido']),
        fechaCreacion: _toDateTime(raw['fechaCreacion']),
        fechaActualizacion: _toDateTime(raw['fechaActualizacion']),
        creadoPor: _auditEmail(raw['creadoPor']),
        modificadoPor: _auditEmail(raw['modificadoPor']),
      );
}

/// Parser de páginas Spring → [PageResult] (RF-02.4).
///
/// La lista de recorridos usa `content/totalElements/totalPages/number/
/// size/first/last` según el contrato; el parser es tolerante si el
/// backend omite campos.
PageResult<T> parsePage<T>(
  Response<Map<String, dynamic>> response,
  T Function(Map<String, dynamic>) mapItem,
) {
  final Map<String, dynamic> body = response.data ?? <String, dynamic>{};
  final List<Map<String, dynamic>> items = (body['content'] as List? ?? <Object?>[])
      .whereType<Map>()
      .map((Map e) => Map<String, dynamic>.from(e))
      .toList();
  return PageResult<T>(
    content: items.map(mapItem).toList(growable: false),
    totalElements: _toInt(body['totalElements']),
    totalPages: _toInt(body['totalPages']),
    number: _toInt(body['number']),
    size: _toInt(body['size']),
    first: body['first'] as bool? ?? _toInt(body['number']) == 0,
    last: body['last'] as bool? ?? true,
  );
}

/// Filtra la lista cargada por matrícula de vehículo o nombre de chofer
/// (RF-02.7 — búsqueda rápida client-side sobre la página ya recibida).
List<T> filtrarBusqueda<T>(
  List<T> items,
  String query,
  String Function(T) matcher,
) {
  final String q = query.trim().toLowerCase();
  if (q.isEmpty) return items;
  return items.where((T item) => matcher(item).toLowerCase().contains(q)).toList();
}

// ---------------------------------------------------------------------------
// helpers tolerantes
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

DateTime? _toDate(Object? value) {
  final String? s = value as String?;
  if (s == null || s.isEmpty) return null;
  return DateTime.tryParse(s);
}

DateTime? _toDateTime(Object? value) => _toDate(value);

String? _auditEmail(Object? nested) {
  if (nested is Map && nested['email'] is String) {
    return nested['email'] as String;
  }
  return null;
}
