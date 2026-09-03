/// Almacenamiento del token JWT — RF-01.2.
///
/// El token se guarda en `flutter_secure_storage` (Android Keystore /
/// iOS Keychain), nunca en `SharedPreferences` (RNF-03).
/// Incluye caché en memoria para no leer del almacenamiento cifrado
/// en cada request del [AuthInterceptor].
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage();

  static const String _key = 'auth.jwt';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.whenUnlocked,
    ),
  );

  String? _cached;

  @override
  Future<String?> read() async {
    if (_cached != null) return _cached;
    _cached = await _storage.read(key: _key);
    return _cached;
  }

  @override
  Future<void> write(String token) async {
    _cached = token;
    await _storage.write(key: _key, value: token);
  }

  @override
  Future<void> clear() async {
    _cached = null;
    await _storage.delete(key: _key);
  }
}

final Provider<TokenStorage> tokenStorageProvider =
    Provider<TokenStorage>((Ref ref) => SecureTokenStorage());
