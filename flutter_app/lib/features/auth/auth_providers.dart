/// Composition root del feature `auth`: únicos providers concretos.
///
/// La capa de dominio (use cases) queda libre de dependencias de `data`;
/// todo el cableado vive aquí.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/change_password.dart';
import 'domain/usecases/get_current_user.dart';
import 'domain/usecases/login.dart';
import 'domain/usecases/logout.dart';

// Repositorio (implementación concreta — ya exportada por data/).
export 'data/repositories/auth_repository_impl.dart' show authRepositoryProvider;

final Provider<LoginUseCase> loginUseCaseProvider = Provider<LoginUseCase>(
  (Ref ref) => LoginUseCase(ref.watch(authRepositoryProvider)),
);

final Provider<LogoutUseCase> logoutUseCaseProvider = Provider<LogoutUseCase>(
  (Ref ref) => LogoutUseCase(ref.watch(authRepositoryProvider)),
);

final Provider<GetCurrentUserUseCase> getCurrentUserUseCaseProvider =
    Provider<GetCurrentUserUseCase>(
  (Ref ref) => GetCurrentUserUseCase(ref.watch(authRepositoryProvider)),
);

final Provider<ChangePasswordUseCase> changePasswordUseCaseProvider =
    Provider<ChangePasswordUseCase>(
  (Ref ref) => ChangePasswordUseCase(ref.watch(authRepositoryProvider)),
);
