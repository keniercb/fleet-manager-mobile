/// Validadores de formularios compartidos (RF-01.1 / RF-01.5 / RF-02.3).
///
/// Las mismas reglas se replican en la demo web para que la evaluación
/// sea equivalente.
class Validators {
  Validators._();

  static final RegExp _emailRegExp = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  /// La API exige `email` con formato válido y no vacío (LoginRequestDto).
  static String? email(String? value) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return 'El email es obligatorio.';
    if (!_emailRegExp.hasMatch(v)) return 'Ingrese un email válido.';
    return null;
  }

  /// La API exige `password` no vacío en el login; para la nueva contraseña
  /// en el cambio, `UserRequest.password` define `minLength: 6`.
  static String? password(String? value, {bool isLogin = true}) {
    final String v = value ?? '';
    if (v.isEmpty) return 'La contraseña es obligatoria.';
    if (!isLogin && v.length < 6) {
      return 'Debe tener al menos 6 caracteres.';
    }
    return null;
  }

  static String? required(String? value, {String label = 'Este campo'}) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return '$label es obligatorio.';
    return null;
  }

  // -------------------------------------------------------------------------
  // RF-02.3 — validaciones del formulario de recorridos
  // (contratos de RecorridoRequest en api-docs.json)
  // -------------------------------------------------------------------------

  /// `kilometros`: int32 con `minimum: 1` (obligatorio).
  static String? kilometros(String? value) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return 'Los kilómetros son obligatorios.';
    final int? n = int.tryParse(v);
    if (n == null) return 'Debe ser un número entero.';
    if (n < 1) return 'Debe ser mayor o igual a 1.';
    return null;
  }

  /// `litrosAbastecidos`: number con `minimum: 0` (opcional: vacío = sin
  /// abastecimiento).
  static String? litros(String? value, {bool required_ = false}) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) {
      return required_ ? 'Los litros son obligatorios.' : null;
    }
    final double? n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null) return 'Debe ser un número válido.';
    if (n < 0) return 'No puede ser negativo.';
    return null;
  }

  /// `importeAbastecido`: double ≥ 0 (opcional).
  static String? importe(String? value) => litros(value, required_: false);

  /// Longitud máxima de campos de texto (`numeroChip` ≤50,
  /// `lugarAbastecimiento` ≤100).
  static String? maxLen(
    String? value,
    int max, {
    String label = 'Este campo',
  }) {
    final String v = value?.trim() ?? '';
    if (v.length > max) return '$label no puede exceder $max caracteres.';
    return null;
  }

  /// `fecha` (formato date `yyyy-MM-dd`): obligatoria y no futura (RF-02.3).
  static String? fechaNoFutura(DateTime? value, {DateTime? now}) {
    final DateTime today = _dateOnly(now ?? DateTime.now());
    if (value == null) return 'La fecha es obligatoria.';
    final DateTime d = _dateOnly(value);
    if (d.isAfter(today)) return 'La fecha no puede ser futura.';
    return null;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
