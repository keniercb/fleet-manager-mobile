/// Estado y lógica del formulario de cambio de contraseña (RF-01.5).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/validators.dart';
import 'session_controller.dart';

class ChangePasswordFormState {
  const ChangePasswordFormState({
    this.current = '',
    this.next = '',
    this.confirm = '',
    this.obscureCurrent = true,
    this.obscureNext = true,
    this.obscureConfirm = true,
    this.currentError,
    this.nextError,
    this.confirmError,
    this.submitting = false,
    this.serverFailure,
    this.succeeded = false,
  });

  final String current;
  final String next;
  final String confirm;
  final bool obscureCurrent;
  final bool obscureNext;
  final bool obscureConfirm;
  final String? currentError;
  final String? nextError;
  final String? confirmError;
  final bool submitting;
  final Failure? serverFailure;
  final bool succeeded;

  ChangePasswordFormState copyWith({
    String? current,
    String? next,
    String? confirm,
    bool? obscureCurrent,
    bool? obscureNext,
    bool? obscureConfirm,
    String? currentError,
    String? nextError,
    String? confirmError,
    bool? submitting,
    Failure? serverFailure,
    bool? succeeded,
    bool clearCurrentError = false,
    bool clearNextError = false,
    bool clearConfirmError = false,
    bool clearServerFailure = false,
  }) {
    return ChangePasswordFormState(
      current: current ?? this.current,
      next: next ?? this.next,
      confirm: confirm ?? this.confirm,
      obscureCurrent: obscureCurrent ?? this.obscureCurrent,
      obscureNext: obscureNext ?? this.obscureNext,
      obscureConfirm: obscureConfirm ?? this.obscureConfirm,
      currentError:
          clearCurrentError ? null : (currentError ?? this.currentError),
      nextError: clearNextError ? null : (nextError ?? this.nextError),
      confirmError:
          clearConfirmError ? null : (confirmError ?? this.confirmError),
      submitting: submitting ?? this.submitting,
      serverFailure:
          clearServerFailure ? null : (serverFailure ?? this.serverFailure),
      succeeded: succeeded ?? this.succeeded,
    );
  }
}

final NotifierProvider<ChangePasswordController, ChangePasswordFormState>
    changePasswordFormProvider =
    NotifierProvider<ChangePasswordController, ChangePasswordFormState>(
        ChangePasswordController.new);

class ChangePasswordController extends Notifier<ChangePasswordFormState> {
  @override
  ChangePasswordFormState build() => const ChangePasswordFormState();

  void currentChanged(String v) => state = state.copyWith(
      current: v, clearCurrentError: true, clearServerFailure: true);

  void nextChanged(String v) => state =
      state.copyWith(next: v, clearNextError: true, clearServerFailure: true);

  void confirmChanged(String v) => state = state.copyWith(
      confirm: v, clearConfirmError: true, clearServerFailure: true);

  void toggleObscureCurrent() =>
      state = state.copyWith(obscureCurrent: !state.obscureCurrent);

  void toggleObscureNext() =>
      state = state.copyWith(obscureNext: !state.obscureNext);

  void toggleObscureConfirm() =>
      state = state.copyWith(obscureConfirm: !state.obscureConfirm);

  Future<bool> submit() async {
    if (state.submitting) return false;

    // 1) Validaciones de cliente (RF-01.5: longitud, igualdad, distinta).
    final String? currentError = Validators.required(state.current,
        label: 'La contraseña actual');
    final String? nextError =
        Validators.password(state.next, isLogin: false);
    String? confirmError;
    if (state.confirm.isEmpty) {
      confirmError = 'Confirme la nueva contraseña.';
    } else if (state.confirm != state.next) {
      confirmError = 'No coincide con la nueva contraseña.';
    }
    String? distinctError;
    if (currentError == null &&
        nextError == null &&
        state.next == state.current) {
      distinctError = 'Debe ser distinta de la contraseña actual.';
    }

    if (currentError != null ||
        nextError != null ||
        confirmError != null ||
        distinctError != null) {
      state = state.copyWith(
        currentError: currentError,
        nextError: nextError ?? distinctError,
        confirmError: confirmError,
      );
      return false;
    }

    // 2) userId del usuario autenticado (RF-01.3 → RF-01.5).
    final session = ref.read(sessionProvider);
    final SessionAuthenticated? auth =
        session is SessionAuthenticated ? session : null;
    if (auth == null) {
      state = state.copyWith(
        serverFailure:
            const UnauthorizedFailure('Sesión no válida. Inicie sesión.'),
      );
      return false;
    }

    state = state.copyWith(
      submitting: true,
      clearCurrentError: true,
      clearNextError: true,
      clearConfirmError: true,
      clearServerFailure: true,
    );

    final result = await ref.read(changePasswordUseCaseProvider)(
      userId: auth.user.id,
      currentPassword: state.current,
      newPassword: state.next,
      confirmPassword: state.confirm,
    );

    return result.when(
      success: (_) {
        state = state.copyWith(submitting: false, succeeded: true);
        return true;
      },
      failure: (Failure failure) {
        state = state.copyWith(submitting: false, serverFailure: failure);
        return false;
      },
    );
  }

  void reset() => state = const ChangePasswordFormState();
}
