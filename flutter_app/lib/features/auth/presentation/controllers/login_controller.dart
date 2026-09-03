/// Estado y lógica del formulario de login (RF-01.1).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/validators.dart';
import 'session_controller.dart';

class LoginFormState {
  const LoginFormState({
    this.email = '',
    this.password = '',
    this.obscure = true,
    this.emailError,
    this.passwordError,
    this.submitting = false,
    this.serverFailure,
  });

  final String email;
  final String password;
  final bool obscure;
  final String? emailError;
  final String? passwordError;
  final bool submitting;
  final Failure? serverFailure;

  bool get canSubmit =>
      !submitting && email.trim().isNotEmpty && password.isNotEmpty;

  LoginFormState copyWith({
    String? email,
    String? password,
    bool? obscure,
    String? emailError,
    String? passwordError,
    bool? submitting,
    Failure? serverFailure,
    bool clearEmailError = false,
    bool clearPasswordError = false,
    bool clearServerFailure = false,
  }) {
    return LoginFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      obscure: obscure ?? this.obscure,
      emailError: clearEmailError ? null : (emailError ?? this.emailError),
      passwordError:
          clearPasswordError ? null : (passwordError ?? this.passwordError),
      submitting: submitting ?? this.submitting,
      serverFailure:
          clearServerFailure ? null : (serverFailure ?? this.serverFailure),
    );
  }
}

final NotifierProvider<LoginController, LoginFormState> loginFormProvider =
    NotifierProvider<LoginController, LoginFormState>(LoginController.new);

class LoginController extends Notifier<LoginFormState> {
  @override
  LoginFormState build() => const LoginFormState();

  void emailChanged(String value) => state = state.copyWith(
        email: value,
        clearEmailError: true,
        clearServerFailure: true,
      );

  void passwordChanged(String value) => state = state.copyWith(
        password: value,
        clearPasswordError: true,
        clearServerFailure: true,
      );

  void toggleObscure() => state = state.copyWith(obscure: !state.obscure);

  Future<void> submit() async {
    if (state.submitting) return;

    // 1) Validación de cliente (misma lógica que replicará el backend).
    final String? emailError = Validators.email(state.email);
    final String? passwordError = Validators.password(state.password);
    if (emailError != null || passwordError != null) {
      state = state.copyWith(
        emailError: emailError,
        passwordError: passwordError,
      );
      return;
    }

    // 2) Login contra la API.
    state = state.copyWith(
      submitting: true,
      clearEmailError: true,
      clearPasswordError: true,
      clearServerFailure: true,
    );

    final result = await ref.read(sessionProvider.notifier).login(
          email: state.email.trim(),
          password: state.password,
        );

    result.when(
      success: (_) {
        // Éxito: limpiar credenciales en memoria; el router redirige a Home.
        state = const LoginFormState();
      },
      failure: (Failure failure) {
        state = state.copyWith(submitting: false, serverFailure: failure);
      },
    );
  }
}
