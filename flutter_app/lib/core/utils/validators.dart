/// Validadores de formularios compartidos (RF-01.1 / RF-01.5).
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
}
