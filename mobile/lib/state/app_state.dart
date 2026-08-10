import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:mazdek_ai/core/config/app_config.dart';
import 'package:mazdek_ai/core/network/api_client.dart';
import 'package:mazdek_ai/core/services/biometric_service.dart';
import 'package:mazdek_ai/core/services/notification_service.dart';
import 'package:mazdek_ai/core/storage/settings_store.dart';
import 'package:mazdek_ai/core/storage/token_store.dart';
import 'package:mazdek_ai/models/models.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

final class AppState extends ChangeNotifier {
  AppState({required this.api, required this.tokens, required this.settings, required this.biometrics, required this.notifications});
  final ApiClient api;
  final TokenStore tokens;
  final SettingsStore settings;
  final BiometricService biometrics;
  final NotificationService notifications;

  AppUser? user;
  bool initialized = false;
  bool busy = false;
  bool locked = false;
  bool offline = false;
  String? error;
  String? notificationWarning;
  String themeMode = 'system';
  String? chatDraft;
  String? navigationTarget;
  StreamSubscription<String>? _notificationOpenSubscription;

  bool get authenticated => user != null;

  Future<void> initialize() async {
    await notifications.initializeLocal();
    _notificationOpenSubscription ??= notifications.openEvents.listen(_handleNotificationOpen);
    final pendingNotification = notifications.consumePendingOpenPayload();
    if (pendingNotification != null) _handleNotificationOpen(pendingNotification);
    themeMode = await settings.themeMode();
    final stored = await tokens.userJson;
    if (stored != null) {
      try {
        user = AppUser.fromJson(jsonDecode(stored) as Map<String, dynamic>);
      } catch (_) {
        await tokens.clearSession();
        user = null;
      }
      if (user != null) {
        try {
          user = await api.me();
          offline = false;
          await tokens.saveUser(jsonEncode(user!.toJson()));
        } on ApiException catch (exception) {
          if (exception.statusCode == 401 || exception.statusCode == 403) {
            await tokens.clearSession();
            user = null;
          } else {
            offline = true;
            error = 'Sunucuya ulaşılamıyor. Son güvenli veriler salt okunur açıldı.';
          }
        } on SocketException {
          offline = true;
          error = 'İnternet veya sunucu bağlantısı yok. Son güvenli veriler salt okunur açıldı.';
        } on TimeoutException {
          offline = true;
          error = 'Sunucu yanıt vermedi. Son güvenli veriler salt okunur açıldı.';
        } catch (_) {
          offline = true;
          error = 'Sunucu doğrulaması tamamlanamadı. Son güvenli veriler salt okunur açıldı.';
        }
        if (user != null) {
          if (await tokens.biometricEnabled && await biometrics.isAvailable()) locked = true;
          await _activateNotifications();
        }
      }
    }
    initialized = true;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    return _run(() async {
      final auth = await api.login(email, password);
      await tokens.saveSession(accessToken: auth.accessToken, refreshToken: auth.refreshToken, userJson: auth.userJson());
      user = auth.user;
      offline = false;
      locked = false;
      await _activateNotifications();
    });
  }

  Future<bool> appleLogin() async {
    return _run(() async {
      final rawNonce = _nonce();
      final hashed = sha256.convert(utf8.encode(rawNonce)).toString();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: hashed,
        webAuthenticationOptions: Platform.isAndroid && AppConfig.appleServiceId.isNotEmpty && AppConfig.appleRedirectUri.isNotEmpty ? WebAuthenticationOptions(clientId: AppConfig.appleServiceId, redirectUri: Uri.parse(AppConfig.appleRedirectUri)) : null,
      );
      final token = credential.identityToken;
      if (token == null) throw const ApiException('Apple kimlik belirteci alınamadı.');
      final name = [credential.givenName, credential.familyName].whereType<String>().where((e) => e.isNotEmpty).join(' ');
      final auth = await api.appleLogin(identityToken: token, nonce: rawNonce, authorizationCode: credential.authorizationCode, name: name.isEmpty ? null : name);
      await tokens.saveSession(accessToken: auth.accessToken, refreshToken: auth.refreshToken, userJson: auth.userJson());
      user = auth.user;
      offline = false;
      locked = false;
      await _activateNotifications();
    });
  }

  Future<void> _activateNotifications() async {
    if (!await settings.notificationsEnabled()) return;
    try {
      await notifications.initializeRemote();
      await notifications.scheduleDailySummary();
      await notifications.synchronizeOperationalNotifications();
      notificationWarning = null;
    } catch (e) {
      // Bildirim kurulumu oturum açmayı veya finansal verilere erişimi engellememeli.
      notificationWarning = 'Bildirimler şu anda etkinleştirilemedi: $e';
    }
  }

  Future<void> reloadUser() async {
    user = await api.me();
    offline = false;
    if (user != null) await tokens.saveUser(jsonEncode(user!.toJson()));
    notifyListeners();
  }

  Future<void> logout() async {
    await notifications.disposeForLogout();
    await api.logout();
    user = null;
    locked = false;
    notifyListeners();
  }

  Future<bool> unlock() async {
    final ok = await biometrics.authenticate();
    if (ok) { locked = false; notifyListeners(); }
    return ok;
  }

  void lock() {
    if (user != null) { locked = true; notifyListeners(); }
  }

  Future<void> setBiometric(bool enabled) async {
    if (enabled && !await biometrics.isAvailable()) throw const ApiException('Bu cihazda biyometrik doğrulama kullanılamıyor.');
    await tokens.setBiometricEnabled(enabled);
    notifyListeners();
  }

  Future<void> setTheme(String value) async {
    themeMode = value;
    await settings.setThemeMode(value);
    notifyListeners();
  }

  void prepareChat(String prompt) {
    chatDraft = prompt.trim();
    navigationTarget = 'chat';
    notifyListeners();
  }

  String? consumeChatDraft() {
    final value = chatDraft;
    chatDraft = null;
    return value;
  }

  String? consumeNavigationTarget() {
    final value = navigationTarget;
    navigationTarget = null;
    return value;
  }

  void _handleNotificationOpen(String payload) {
    if (payload == 'daily_report') {
      navigationTarget = 'dashboard';
    } else {
      chatDraft = 'Bu bildirimle ilişkili kaydı incele ($payload); güncel durumu, riski ve yapılması gereken işlemi açıkla.';
      navigationTarget = 'chat';
    }
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    busy = true; error = null; notifyListeners();
    try { await action(); return true; }
    catch (e) { error = e.toString(); return false; }
    finally { busy = false; notifyListeners(); }
  }


  @override
  void dispose() {
    unawaited(_notificationOpenSubscription?.cancel());
    unawaited(notifications.shutdown());
    super.dispose();
  }

  String _nonce([int length = 32]) {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
