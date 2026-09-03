/// Widgets de formulario reutilizables del feature auth (Fase 0.2).
import 'package:flutter/material.dart';

/// Campo de texto con etiqueta, error y estilo consistente del design system.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.autofocus = false,
    this.autocorrect = true,
    this.obscureText = false,
  });

  final String label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool autofocus;
  final bool autocorrect;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      autofocus: autofocus,
      autocorrect: autocorrect,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
    );
  }
}

/// Campo de contraseña con botón de visibilidad (RF-01.1 / RF-01.5).
/// El estado `obscure` lo controla el controlador del formulario
/// (no estado interno), para que sobreviva a recomposiciones.
class AppPasswordField extends StatelessWidget {
  const AppPasswordField({
    super.key,
    required this.label,
    required this.obscure,
    required this.onObscureToggle,
    this.errorText,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.prefixIcon,
    this.enabled = true,
  });

  final String label;
  final bool obscure;
  final VoidCallback onObscureToggle;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Widget? prefixIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      errorText: errorText,
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      obscureText: obscure,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      prefixIcon: prefixIcon,
      textInputAction: textInputAction,
      suffixIcon: IconButton(
        icon: Icon(
          obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
        tooltip: obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
        onPressed: onObscureToggle,
      ),
    );
  }
}
