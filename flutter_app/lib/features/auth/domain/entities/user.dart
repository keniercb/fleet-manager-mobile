/// Entidades del dominio de autenticación (RF-01.3).
///
/// Modelo mapeado 1:1 con los esquemas del `api-docs.json`:
///   UserResponse { id, email, empresa?, roles[], activo, audit }
///   RoleResponse { id, name, description, permissions[] }
///   PermissionResponse { id, name, description }
///   EmpresaResponse { id, codigo, nombre, ... }
///
/// Son entidades **inmutables e independientes** de JSON/Dio/Flutter
/// (Clean Architecture): los mapeos viven en la capa `data`.
class Permission {
  const Permission({required this.id, required this.name});

  final int id;
  final String name;
}

class Role {
  const Role({
    required this.id,
    required this.name,
    this.description,
    this.permissions = const <Permission>[],
  });

  final int id;
  final String name;
  final String? description;
  final List<Permission> permissions;
}

class Empresa {
  const Empresa({
    required this.id,
    this.codigo,
    this.nombre,
  });

  final int id;
  final String? codigo;
  final String? nombre;
}

class User {
  const User({
    required this.id,
    required this.email,
    required this.activo,
    this.empresa,
    this.roles = const <Role>[],
  });

  final int id;
  final String email;
  final Empresa? empresa;
  final List<Role> roles;
  final bool activo;

  List<String> get roleNames =>
      roles.map((Role r) => r.name).toList(growable: false);
}

/// Capacidades habilitadas por rol — RF-01.3 («la app habilita features
/// según roles»).
///
/// ⚠ Los nombres reales de roles se definieron en el backend (`/api/roles`).
/// Este mapeo es el ÚNICO punto a ajustar cuando se confirmen; mientras
/// tanto es «fail-open» (permite todo lo operativo) para no bloquear la
/// Fase 1. Fase 2 lo consumirá para ocultar/mostrar módulos.
class UserCapabilities {
  const UserCapabilities({
    required this.isCompanyAdmin,
    required this.canManageFleet,
    required this.canRegisterTrips,
    required this.canViewReports,
  });

  final bool isCompanyAdmin;
  final bool canManageFleet;
  final bool canRegisterTrips;
  final bool canViewReports;

  static UserCapabilities fromUser(User user) {
    final Set<String> names = user.roleNames.toSet();
    final bool hasKnownRole = names.isNotEmpty &&
        names.any(_knownRolePatterns.contains);

    // Fail-open documentado: sin roles conocidos no bloqueamos la operación.
    if (!hasKnownRole) {
      return const UserCapabilities(
        isCompanyAdmin: false,
        canManageFleet: true,
        canRegisterTrips: true,
        canViewReports: true,
      );
    }

    final bool admin = names.any(_isAdmin);
    final bool supervisor = names.any(_isSupervisor);
    final bool chofer = names.any(_isChofer);

    return UserCapabilities(
      isCompanyAdmin: admin,
      canManageFleet: admin || supervisor,
      canRegisterTrips: admin || supervisor || chofer,
      canViewReports: admin || supervisor,
    );
  }

  static const Set<String> _knownRolePatterns = <String>{
    'admin', 'administrador', 'jefe', 'supervisor', 'chofer', 'chofé',
    'driver', 'operador', 'empresa', 'user', 'usuario',
  };

  static bool _isAdmin(String n) =>
      n.toLowerCase().contains('admin') || n.toLowerCase().contains('gerente');

  static bool _isSupervisor(String n) =>
      n.toLowerCase().contains('jefe') || n.toLowerCase().contains('supervisor');

  static bool _isChofer(String n) =>
      n.toLowerCase().contains('chofer') ||
      n.toLowerCase().contains('chofé') ||
      n.toLowerCase().contains('driver');
}
