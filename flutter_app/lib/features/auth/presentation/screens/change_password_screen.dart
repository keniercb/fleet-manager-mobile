/// Pantalla de cambio de contraseña (RF-01.5).
///
/// Validaciones de cliente:
///   - actual obligatoria
///   - nueva ≥ 6 caracteres (contrato API `UserRequest.password.minLength`)
///   - confirmación idéntica
///   - nueva distinta de la actual
/// Errores de servidor (400 con fieldErrors, 401, 500) se muestran en banner.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/change_password_controller.dart';
import '../widgets/app_text_field.dart';
import '../widgets/flow_banner.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final TextEditingController _currentCtrl = TextEditingController();
  final TextEditingController _nextCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _currentCtrl.dispose();
    _nextCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final bool ok =
        await ref.read(changePasswordFormProvider.notifier).submit();
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada correctamente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      ref.read(changePasswordFormProvider.notifier).reset();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ChangePasswordFormState form = ref.watch(changePasswordFormProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (form.serverFailure != null)
                    FlowBanner(
                      message: form.serverFailure!.userMessage,
                      kind: FlowBannerKind.warning,
                    ),
                  if (form.succeeded)
                    const FlowBanner(
                      message: 'Contraseña actualizada correctamente.',
                      kind: FlowBannerKind.success,
                    ),

                  Text(
                    'Por seguridad, elija una contraseña de al menos 6 caracteres '
                    'y distinta de la anterior.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),

                  AppPasswordField(
                    label: 'Contraseña actual',
                    controller: _currentCtrl,
                    obscure: form.obscureCurrent,
                    onObscureToggle: ref
                        .read(changePasswordFormProvider.notifier)
                        .toggleObscureCurrent,
                    onChanged: ref
                        .read(changePasswordFormProvider.notifier)
                        .currentChanged,
                    textInputAction: TextInputAction.next,
                    enabled: !form.submitting,
                    errorText: form.currentError,
                  ),
                  const SizedBox(height: 16),

                  AppPasswordField(
                    label: 'Nueva contraseña',
                    controller: _nextCtrl,
                    obscure: form.obscureNext,
                    onObscureToggle: ref
                        .read(changePasswordFormProvider.notifier)
                        .toggleObscureNext,
                    onChanged: ref
                        .read(changePasswordFormProvider.notifier)
                        .nextChanged,
                    textInputAction: TextInputAction.next,
                    enabled: !form.submitting,
                    errorText: form.nextError,
                    prefixIcon:
                        const Icon(Icons.enhanced_encryption_rounded),
                  ),
                  const SizedBox(height: 16),

                  AppPasswordField(
                    label: 'Confirmar nueva contraseña',
                    controller: _confirmCtrl,
                    obscure: form.obscureConfirm,
                    onObscureToggle: ref
                        .read(changePasswordFormProvider.notifier)
                        .toggleObscureConfirm,
                    onChanged: ref
                        .read(changePasswordFormProvider.notifier)
                        .confirmChanged,
                    onSubmitted: () => _submit(),
                    textInputAction: TextInputAction.done,
                    enabled: !form.submitting,
                    errorText: form.confirmError,
                  ),
                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed:
                        form.submitting ? null : () => _submit(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: form.submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : const Text(
                            'Guardar cambios',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
