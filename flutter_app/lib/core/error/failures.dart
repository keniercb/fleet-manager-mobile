/// Jerarquía de errores del dominio (ADR-06: `Failure` tipados en vez de excepciones).
///
/// Diseñada para ser tolerante con el backend (Riesgo R2 del plan): el OpenAPI
/// no define cuerpos de error, por lo que el mapeo intenta, en orden:
///   1. ProblemDetail RFC-7807  ({type, title, detail, status})
///   2. Cuerpo estilo Spring    ({timestamp, status, error, message, path})
///   3. Errores de campo        ({errors: [{field, defaultMessage}]} o {campo: msg})
///   4. Fallback genérico.
import 'dart:io' show SocketException, HandshakeException;

import 'package:dio/dio.dart';

sealed class Failure {
  const Failure(this.userMessage);

  /// Mensaje listo para mostrar al usuario (i18n se aplicará en Fase 5).
  final String userMessage;

  @override
  String toString() => '$runtimeType($userMessage)';
}

/// Sin conexión con el servidor (RNF-04).
class NetworkFailure extends Failure {
  const NetworkFailure([
    super.userMessage =
        'Sin conexión con el servidor. Verifique su red e inténtelo de nuevo.',
  ]);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure([
    super.userMessage = 'El servidor tardó demasiado en responder. Reintente.',
  ]);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([
    super.userMessage = 'Credenciales inválidas o sesión expirada.',
  ]);
}

class ForbiddenFailure extends Failure {
  const ForbiddenFailure([
    super.userMessage = 'No tiene permisos para realizar esta operación.',
  ]);
}

/// Error del servidor con código HTTP conocido (500, 502, 503, …).
class ServerFailure extends Failure {
  const ServerFailure({required this.statusCode, required super.userMessage});

  final int statusCode;
}

/// Error de validación (400) con errores por campo si el backend los envía.
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.userMessage,
    this.fieldErrors = const <String, String>{},
  });

  /// Mapa campo → mensaje (ej.: `{"email": "must be a well-formed email"}`).
  final Map<String, String> fieldErrors;
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.userMessage = 'Ocurrió un error inesperado.']);
}

/// Punto único de traducción de errores de red → [Failure].
/// Toda la capa de datos usa esta función; la UI nunca conoce `DioException`.
Failure mapDioError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutFailure();

      case DioExceptionType.connectionError:
        return const NetworkFailure();

      case DioExceptionType.badCertificate:
        return const ServerFailure(
          statusCode: 0,
          userMessage: 'Certificado del servidor no válido.',
        );

      case DioExceptionType.cancel:
        return const UnknownFailure('Solicitud cancelada.');

      case DioExceptionType.badResponse:
        return _mapBadResponse(error.response);

      case DioExceptionType.unknown:
        final Object? inner = error.error;
        if (inner is SocketException || inner is HandshakeException) {
          return const NetworkFailure();
        }
        return const NetworkFailure();
    }
  }
  return UnknownFailure(error.toString());
}

Failure _mapBadResponse(Response<dynamic>? response) {
  final int status = response?.statusCode ?? 500;
  final Map<String, dynamic>? body = _asJsonMap(response?.data);
  final String? message = _extractMessage(body);

  if (status == 400) {
    return ValidationFailure(
      userMessage: message ?? 'Revise los datos del formulario.',
      fieldErrors: _extractFieldErrors(body),
    );
  }
  if (status == 401) {
    return const UnauthorizedFailure();
  }
  if (status == 403) {
    return const ForbiddenFailure();
  }
  if (status == 404) {
    return ServerFailure(
        statusCode: status, userMessage: 'Recurso no encontrado.');
  }
  if (status >= 500) {
    return ServerFailure(
      statusCode: status,
      userMessage:
          message ?? 'Error interno del servidor ($status). Intente más tarde.',
    );
  }
  return ServerFailure(
    statusCode: status,
    userMessage: message ?? 'Error inesperado (HTTP $status).',
  );
}

Map<String, dynamic>? _asJsonMap(Object? data) {
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  return null;
}

/// Extrae el mensaje humano de un cuerpo de error tolerante (R2).
String? _extractMessage(Map<String, dynamic>? body) {
  if (body == null) return null;
  // RFC 7807 → detail | Spring → message | genérico → error | problem → title
  for (final String key in const <String>['detail', 'message', 'error', 'title']) {
    final Object? value = body[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
  }
  return null;
}

/// Extrae errores por campo de los formatos más comunes de Spring:
///   {errors: [{field: 'email', defaultMessage: '...'}]}
///   {fieldErrors: {email: '...'}}
Map<String, String> _extractFieldErrors(Map<String, dynamic>? body) {
  if (body == null) return const <String, String>{};

  final Map<String, String> out = <String, String>{};

  final Object? errors = body['errors'];
  if (errors is List) {
    for (final Object? item in errors) {
      if (item is Map) {
        final Object? field = item['field'] ?? item['propertyPath'];
        final Object? msg =
            item['defaultMessage'] ?? item['message'] ?? item['detail'];
        if (field is String && msg is String) out[field] = msg;
      }
    }
  }

  final Object? fieldErrors = body['fieldErrors'];
  if (fieldErrors is Map) {
    fieldErrors.forEach((Object? k, Object? v) {
      if (k is String && v is String) out[k] = v;
    });
  }

  return out;
}
