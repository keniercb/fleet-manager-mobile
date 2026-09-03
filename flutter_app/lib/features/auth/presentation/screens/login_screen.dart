/// Pantalla de Login (RF-01.1).
///
/// Estados soportados:
///  - Validación inline de email/contraseña (misma lógica que el backend).
///  - `submitting` → botón con spinner, deshabilitado.
///  - Fallo de servidor → banner con `Failure.userMessage`
///    (401 → «Credenciales inválidas…», red → «Sin conexión…», R2).
///  - Banner de sesión expirada cuando el redirect vino de un 401 (RF-01.6).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../controllers/login_controller.dart';
import '../controllers/session_controller.dart';
import '../widgets/app_text_field.dart';
import '../widgets/flow_banner.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LoginFormState form = ref.watch(loginFormProvider);
    final SessionState session = ref.watch(sessionProvider);

    final bool showExpiredBanner = session is SessionUnauthenticated &&
        session.reason == SessionEndReason.expired;
    final bool showLoggedOutBanner = session is SessionUnauthenticated &&
        session.reason == SessionEndReason.loggedOut;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // ---------- Marca ----------
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.local_shipping_rounded,
                        size: 36,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Iniciar sesión',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Acceda con sus credenciales de la empresa',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ---------- Banners ----------
                    if (showExpiredBanner)
                      const FlowBanner(
                        message:
                            'Tu sesión ha expirado. Vuelve a iniciar sesión.',
                        kind: FlowBannerKind.warning,
                      ),
                    if (showLoggedOutBanner)
                      const FlowBanner(
                        message: 'Sesión cerrada correctamente.',
                        kind: FlowBannerKind.success,
                      ),
                    if (form.serverFailure != null)
                      FlowBanner(
                        message: form.serverFailure!.userMessage,
                        kind: FlowBannerKind.warning,
                      ),

                    // ---------- Formulario ----------
                    AppTextField(
                      label: 'Email',
                      hint: 'usuario@empresa.cu',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      errorText: form.emailError,
                      enabled: !form.submitting,
                      autocorrect: false,
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                      onChanged: ref.read(loginFormProvider.notifier).emailChanged,
                    ),
                    const SizedBox(height: 16),
                    AppPasswordField(
                      label: 'Contraseña',
                      controller: _passwordCtrl,
                      obscure: form.obscure,
                      onObscureToggle:
                          ref.read(loginFormProvider.notifier).toggleObscure,
                      onChanged:
                          ref.read(loginFormProvider.notifier).passwordChanged,
                      onSubmitted: () =>
                          ref.read(loginFormProvider.notifier).submit(),
                      textInputAction: TextInputAction.done,
                      enabled: !form.submitting,
                      errorText: form.passwordError,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                    ),
                    const SizedBox(height: 24),

                    // ---------- Submit ----------
                    FilledButton(
                      onPressed: form.canSubmit
                          ? () => ref.read(loginFormProvider.notifier).submit()
                          : null,
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
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : const Text(
                              'Entrar',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // ---------- Ayuda de integración ----------
                    Text(
                      'Servidor: ${AppConfig.apiBaseUrl}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
