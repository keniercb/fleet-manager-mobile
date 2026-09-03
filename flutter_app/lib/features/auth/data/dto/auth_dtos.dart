/// DTOs + mapeo a entidades del módulo de autenticación.
///
/// Contratos tomados textualmente de `api-docs.json`:
///  - LoginRequestDto      { email, password }                    (POST /api/auth/login)
///  - AuthResponseDto      { token, type, userId, email }         (→ 200)
///  - UserResponse         { id, email, empresa?, roles[], activo } (GET /api/auth/me)
///  - CambioPasswordRequest{ userId, passwordAnterior,
///                           nuevaPassword, confirmacionPassword } (PUT /api/auth/cambiar-password)
///
/// Nota ADR-02: aquí se escriben a mano para que el módulo compile sin
/// `build_runner`. En Fase 0.4 se puede sustituir por generación desde el
/// OpenAPI sin cambiar el resto del código (los mapeos a dominio quedan).
import '../../../domain/entities/auth_session.dart';
import '../../../domain/entities/user.dart';

class LoginRequestDto {
  const LoginRequestDto({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'email': email,
        'password': password,
      };
}

class AuthResponseDto {
  const AuthResponseDto({
    required this.token,
    required this.type,
    required this.userId,
    required this.email,
  });

  final String token;
  final String type;
  final int userId;
  final String email;

  factory AuthResponseDto.fromJson(Map<String, dynamic> json) {
    return AuthResponseDto(
      token: json['token'] as String? ?? '',
      type: json['type'] as String? ?? 'Bearer',
      userId: _toInt(json['userId']),
      email: json['email'] as String? ?? '',
    );
  }

  AuthSession toDomain() => AuthSession(
        token: token,
        tokenType: type,
        userId: userId,
        email: email,
      );
}

class CambioPasswordRequestDto {
  const CambioPasswordRequestDto({
    required this.userId,
    required this.passwordAnterior,
    required this.nuevaPassword,
    required this.confirmacionPassword,
  });

  final int userId;
  final String passwordAnterior;
  final String nuevaPassword;
  final String confirmacionPassword;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'userId': userId,
        'passwordAnterior': passwordAnterior,
        'nuevaPassword': nuevaPassword,
        'confirmacionPassword': confirmacionPassword,
      };
}

// ---------------------------------------------------------------------------
// GET /api/auth/me
// ---------------------------------------------------------------------------

class PermissionDto {
  const PermissionDto({required this.id, required this.name});

  final int id;
  final String name;

  factory PermissionDto.fromJson(Map<String, dynamic> json) => PermissionDto(
        id: _toInt(json['id']),
        name: json['name'] as String? ?? '',
      );

  Permission toDomain() => Permission(id: id, name: name);
}

class RoleDto {
  const RoleDto({
    required this.id,
    required this.name,
    this.description,
    this.permissions = const <PermissionDto>[],
  });

  final int id;
  final String name;
  final String? description;
  final List<PermissionDto> permissions;

  factory RoleDto.fromJson(Map<String, dynamic> json) => RoleDto(
        id: _toInt(json['id']),
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        permissions: _list(json['permissions'])
            .map(PermissionDto.fromJson)
            .toList(),
      );

  Role toDomain() => Role(
        id: id,
        name: name,
        description: description,
        permissions: permissions
            .map((PermissionDto p) => p.toDomain())
            .toList(growable: false),
      );
}

class EmpresaDto {
  const EmpresaDto({required this.id, this.codigo, this.nombre});

  final int id;
  final String? codigo;
  final String? nombre;

  factory EmpresaDto.fromJson(Map<String, dynamic> json) => EmpresaDto(
        id: _toInt(json['id']),
        codigo: json['codigo'] as String?,
        nombre: json['nombre'] as String?,
      );

  Empresa toDomain() =>
      Empresa(id: id, codigo: codigo, nombre: nombre);
}

class UserResponseDto {
  const UserResponseDto({
    required this.id,
    required this.email,
    required this.activo,
    this.empresa,
    this.roles = const <RoleDto>[],
  });

  final int id;
  final String email;
  final bool activo;
  final EmpresaDto? empresa;
  final List<RoleDto> roles;

  factory UserResponseDto.fromJson(Map<String, dynamic> json) {
    return UserResponseDto(
      id: _toInt(json['id']),
      email: json['email'] as String? ?? '',
      activo: json['activo'] as bool? ?? true,
      empresa: json['empresa'] is Map
          ? EmpresaDto.fromJson(Map<String, dynamic>.from(json['empresa'] as Map))
          : null,
      roles: _list(json['roles']).map(RoleDto.fromJson).toList(),
    );
  }

  User toDomain() => User(
        id: id,
        email: email,
        activo: activo,
        empresa: empresa?.toDomain(),
        roles: roles.map((RoleDto r) => r.toDomain()).toList(growable: false),
      );
}

// ---------------------------------------------------------------------------
// helpers tolerantes (los int64 pueden llegar como num/string)
// ---------------------------------------------------------------------------

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((Map e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return <Map<String, dynamic>>[];
}
