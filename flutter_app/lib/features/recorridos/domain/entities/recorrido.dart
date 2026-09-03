/// Entidad del núcleo del negocio: Recorrido (RF-02).
///
/// Contrato `RecorridoResponse` del `api-docs.json`. Los campos
/// `odometroInicial`, `combustibleInicial` y `consumo` son **calculados por
/// el servidor** (R7 del plan): el cliente sólo envía `kilometros` y muestra
/// lo que el backend devuelve.
class Recorrido {
  const Recorrido({
    required this.id,
    required this.fecha,
    required this.kilometros,
    required this.activo,
    this.vehiculo,
    this.chofer,
    this.odometroInicial,
    this.combustibleInicial,
    this.consumo,
    this.litrosAbastecidos,
    this.numeroChip,
    this.lugarAbastecimiento,
    this.tarjeta,
    this.importeAbastecido,
    this.fechaCreacion,
    this.fechaActualizacion,
    this.creadoPor,
    this.modificadoPor,
  });

  final int id;

  /// Referencias embebidas (objetos completos en la respuesta del backend).
  final Vehiculo? vehiculo;
  final Chofer? chofer;

  /// Fecha del recorrido (`date` → `yyyy-MM-dd`).
  final DateTime fecha;
  final int kilometros;

  // ----- Calculados por el servidor (R7) -----
  final int? odometroInicial;
  final double? combustibleInicial;
  final double? consumo;

  // ----- Abastecimiento opcional (RF-02.2) -----
  final double? litrosAbastecidos;
  final String? numeroChip;
  final String? lugarAbastecimiento;
  final TarjetaCombustible? tarjeta;
  final double? importeAbastecido;

  final bool activo;

  // ----- Auditoría (RF-02.5) -----
  final DateTime? fechaCreacion;
  final DateTime? fechaActualizacion;

  /// `UserAuditResponse { id, email }` → se muestra el email.
  final String? creadoPor;
  final String? modificadoPor;

  bool get tieneAbastecimiento =>
      (litrosAbastecidos ?? 0) > 0 || (importeAbastecido ?? 0) > 0;
}

/// Datos de entrada del formulario de recorrido (RF-02.1 / RF-02.2).
///
/// Contrato `RecorridoRequest`: required `fecha`, `kilometros`, `vehiculoId`;
/// el resto es opcional. Se usa igual para crear (POST) y actualizar (PUT).
class RecorridoInput {
  const RecorridoInput({
    required this.vehiculoId,
    required this.fecha,
    required this.kilometros,
    this.choferId,
    this.litrosAbastecidos,
    this.numeroChip,
    this.lugarAbastecimiento,
    this.tarjetaCombustibleId,
    this.importeAbastecido,
  });

  final int vehiculoId;
  final int? choferId;
  final DateTime fecha;
  final int kilometros;
  final double? litrosAbastecidos;
  final String? numeroChip;
  final String? lugarAbastecimiento;
  final int? tarjetaCombustibleId;
  final double? importeAbastecido;

  /// Serialización `yyyy-MM-dd` exigida por el OpenAPI (`format: date`).
  String get fechaIso {
    final String m = fecha.month.toString().padLeft(2, '0');
    final String d = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$m-$d';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'vehiculoId': vehiculoId,
        if (choferId != null) 'choferId': choferId,
        'fecha': fechaIso,
        'kilometros': kilometros,
        if (litrosAbastecidos != null) 'litrosAbastecidos': litrosAbastecidos,
        if (numeroChip != null && numeroChip!.isNotEmpty)
          'numeroChip': numeroChip,
        if (lugarAbastecimiento != null && lugarAbastecimiento!.isNotEmpty)
          'lugarAbastecimiento': lugarAbastecimiento,
        if (tarjetaCombustibleId != null)
          'tarjetaCombustibleId': tarjetaCombustibleId,
        if (importeAbastecido != null)
          'importeAbastecido': importeAbastecido,
      };
}
