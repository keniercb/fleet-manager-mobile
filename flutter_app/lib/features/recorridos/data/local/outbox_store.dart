/// Outbox local v1 (Fase 2.5) — cola FIFO de recorridos creados sin red.
///
/// Comportamiento:
///  - El formulario intenta POST; si falla por red (`NetworkFailure` /
///    `TimeoutFailure`), el input se encola con un id local.
///  - `SyncManager` (outbox_controller) reenvía en FIFO cuando hay red:
///    al cargar la lista si hubo éxito previo, al reintentar manualmente
///    desde el banner de pendientes, o al detectar que una petición vuelve
///    a funcionar.
///  - Persistencia: `flutter_secure_storage` (mismo almacén cifrado del
///    token, RNF-03) con la cola serializada a JSON. Cuando llegue Drift
///    (Fase 6) la tabla `outbox` sustituye a este store sin cambiar la
///    interfaz.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/recorrido.dart';

/// Un recorrido pendiente de sincronizar.
class PendingRecorrido {
  const PendingRecorrido({
    required this.localId,
    required this.input,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  /// Identificador local (`local-<ms>-<sec>`), mostrado en la UI como
  /// «pendiente de sync» hasta que el servidor asigne el id real.
  final String localId;
  final RecorridoInput input;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  PendingRecorrido copyWith({int? attempts, String? lastError}) =>
      PendingRecorrido(
        localId: localId,
        input: input,
        createdAt: createdAt,
        attempts: attempts ?? this.attempts,
        lastError: lastError,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'localId': localId,
        'createdAt': createdAt.toIso8601String(),
        'attempts': attempts,
        'lastError': lastError,
        'input': input.toJson(),
      };

  factory PendingRecorrido.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> inputJson =
        Map<String, dynamic>.from(json['input'] as Map);
    return PendingRecorrido(
      localId: json['localId'] as String? ?? 'local',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
              DateTime.now(),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] as String?,
      input: RecorridoInput(
        vehiculoId: (inputJson['vehiculoId'] as num?)?.toInt() ?? 0,
        choferId: inputJson['choferId'] == null
            ? null
            : (inputJson['choferId'] as num).toInt(),
        fecha: DateTime.tryParse(inputJson['fecha'] as String? ?? '') ??
            DateTime.now(),
        kilometros: (inputJson['kilometros'] as num?)?.toInt() ?? 1,
        litrosAbastecidos: inputJson['litrosAbastecidos'] == null
            ? null
            : (inputJson['litrosAbastecidos'] as num).toDouble(),
        numeroChip: inputJson['numeroChip'] as String?,
        lugarAbastecimiento: inputJson['lugarAbastecimiento'] as String?,
        tarjetaCombustibleId: inputJson['tarjetaCombustibleId'] == null
            ? null
            : (inputJson['tarjetaCombustibleId'] as num).toInt(),
        importeAbastecido: inputJson['importeAbastecido'] == null
            ? null
            : (inputJson['importeAbastecido'] as num).toDouble(),
      ),
    );
  }
}

abstract class OutboxStore {
  Future<List<PendingRecorrido>> load();
  Future<void> save(List<PendingRecorrido> queue);
}

/// Almacén cifrado local (flutter_secure_storage).
class SecureOutboxStore implements OutboxStore {
  SecureOutboxStore();

  static const String _key = 'recorridos.outbox.v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.whenUnlocked,
    ),
  );

  @override
  Future<List<PendingRecorrido>> load() async {
    final String? raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return <PendingRecorrido>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <PendingRecorrido>[];
      return decoded
          .whereType<Map>()
          .map((Map e) =>
              PendingRecorrido.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on FormatException {
      // Cola corrupta: se descarta (mejor que bloquear la app).
      return <PendingRecorrido>[];
    }
  }

  @override
  Future<void> save(List<PendingRecorrido> queue) async {
    final String raw = jsonEncode(
      queue.map((PendingRecorrido p) => p.toJson()).toList(),
    );
    await _storage.write(key: _key, value: raw);
  }
}

final Provider<OutboxStore> outboxStoreProvider =
    Provider<OutboxStore>((Ref ref) => SecureOutboxStore());
