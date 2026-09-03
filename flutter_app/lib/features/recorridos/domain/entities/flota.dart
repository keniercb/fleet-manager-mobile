/// Entidades de flota usadas por RF-02 (formularios y listado de recorridos).
///
/// Contratos del `api-docs.json`:
///   VehiculoResponse            { id, empresa, tipoVehiculo, marca, chofer,
///                                 tipoCombustible, matricula, modelo,
///                                 numeroMotor, odometro, combustible,
///                                 ultimoMantenimiento,
///                                 odometroUltimoMantenimiento,
///                                 indiceConsumo, activo, audit }
///   ChoferResponse              { id, empresa, nombre, apellidos,
///                                 carneIdentidad, numeroLicencia,
///                                 categorias, activo, audit }
///   TarjetaCombustibleResponse  { id, numero, saldo, currency, empresa,
///                                 activo, audit }
///
/// Para RF-02 sólo se materializan los campos que la feature consume; la
/// ficha completa de vehículo (RF-03) ampliará estas entidades.
class Vehiculo {
  const Vehiculo({
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
    this.ultimoMantenimiento,
    this.chofer,
  });

  final int id;
  final String matricula;

  /// Odómetro actual (km) — fuente de la advertencia R7 del formulario.
  final int odometro;
  final bool activo;

  final String? modelo;
  final String? marcaNombre;
  final String? tipoVehiculoNombre;
  final String? tipoCombustibleNombre;

  /// Combustible actual en el tanque (L) — el servidor lo consume/actualiza.
  final double? combustible;

  /// Índice de consumo de la norma (L/km) — dato de la empresa.
  final double? indiceConsumo;
  final DateTime? ultimoMantenimiento;
  final Chofer? chofer;

  String get etiqueta => (modelo == null || modelo!.isEmpty)
      ? matricula
      : '$matricula · $modelo';

  String get descripcionFlota {
    final List<String> partes = <String>[
      if (marcaNombre != null && marcaNombre!.isNotEmpty) marcaNombre!,
      if (modelo != null && modelo!.isNotEmpty) modelo!,
      if (tipoVehiculoNombre != null && tipoVehiculoNombre!.isNotEmpty)
        tipoVehiculoNombre!,
    ];
    return partes.join(' · ');
  }
}

class Chofer {
  const Chofer({
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

  String get nombreCompleto => '$nombre $apellidos'.trim();
}

class TarjetaCombustible {
  const TarjetaCombustible({
    required this.id,
    required this.numero,
    required this.saldo,
    required this.activo,
    this.isoCode,
  });

  final int id;
  final String numero;

  /// Saldo disponible (double del backend — R8: formatear con `intl`).
  final double saldo;
  final String? isoCode;
  final bool activo;

  String get etiqueta => isoCode == null || isoCode!.isEmpty
      ? numero
      : '$numero · $isoCode';
}
