import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

final class OfflineCache {
  OfflineCache(this._secureStorage);
  final FlutterSecureStorage _secureStorage;
  static const _keyName = 'offline_cache_key_v1';
  final _cipher = AesGcm.with256bits();

  Future<SecretKey> _key() async {
    final saved = await _secureStorage.read(key: _keyName);
    if (saved != null) return SecretKey(base64Decode(saved));
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    await _secureStorage.write(key: _keyName, value: base64Encode(bytes));
    return SecretKey(bytes);
  }

  Future<File> _file(String cacheKey) async {
    final directory = await getApplicationSupportDirectory();
    final safe = base64Url.encode(utf8.encode(cacheKey)).replaceAll('=', '');
    return File('${directory.path}/cache_$safe.bin');
  }

  Future<void> write(String cacheKey, String jsonText) async {
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(utf8.encode(jsonText), secretKey: await _key(), nonce: nonce);
    final payload = <int>[...nonce, ...box.mac.bytes, ...box.cipherText];
    final file = await _file(cacheKey);
    await file.writeAsBytes(payload, flush: true);
  }

  Future<String?> read(String cacheKey) async {
    try {
      final file = await _file(cacheKey);
      if (!await file.exists()) return null;
      final data = await file.readAsBytes();
      if (data.length < 28) return null;
      final nonce = data.sublist(0, 12);
      final mac = Mac(data.sublist(12, 28));
      final cipherText = data.sublist(28);
      final clear = await _cipher.decrypt(SecretBox(cipherText, nonce: nonce, mac: mac), secretKey: await _key());
      return utf8.decode(clear);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    final directory = await getApplicationSupportDirectory();
    if (!await directory.exists()) return;
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.split('/').last.startsWith('cache_')) {
        try { await entity.delete(); } catch (_) {}
      }
    }
  }
}
