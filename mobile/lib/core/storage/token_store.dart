import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final class TokenStore {
  TokenStore(this._storage);
  final FlutterSecureStorage _storage;

  static const _access = 'access_token';
  static const _refresh = 'refresh_token';
  static const _user = 'current_user';
  static const _biometric = 'biometric_enabled';

  Future<String?> get accessToken => _storage.read(key: _access);
  Future<String?> get refreshToken => _storage.read(key: _refresh);
  Future<String?> get userJson => _storage.read(key: _user);
  Future<bool> get biometricEnabled async => (await _storage.read(key: _biometric)) == 'true';

  Future<void> saveSession({required String accessToken, required String refreshToken, required String userJson}) async {
    await Future.wait([
      _storage.write(key: _access, value: accessToken),
      _storage.write(key: _refresh, value: refreshToken),
      _storage.write(key: _user, value: userJson),
    ]);
  }

  Future<void> saveUser(String value) => _storage.write(key: _user, value: value);
  Future<void> setBiometricEnabled(bool value) => _storage.write(key: _biometric, value: '$value');

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _access),
      _storage.delete(key: _refresh),
      _storage.delete(key: _user),
    ]);
  }
}
