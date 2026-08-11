import 'package:shared_preferences/shared_preferences.dart';
import 'package:mazdek_ai/core/config/app_config.dart';

final class SettingsStore {
  static const _apiKey = 'api_base_url';
  static const _themeKey = 'theme_mode';
  static const _notificationsKey = 'notifications_enabled';
  static const _scheduledNotificationIdsKey = 'scheduled_notification_ids';

  Future<String> apiBaseUrl() async {
    if (!AppConfig.allowsCustomApiUrl) return AppConfig.productionApiUrl;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_apiKey);
    if (stored == null || !AppConfig.isSecureApiUrl(stored)) return AppConfig.defaultApiUrl;
    return stored.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  Future<void> setApiBaseUrl(String value) async {
    if (!AppConfig.allowsCustomApiUrl) {
      throw UnsupportedError('Yayın sürümünde API adresi değiştirilemez.');
    }
    final normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    if (!AppConfig.isSecureApiUrl(normalized)) {
      throw ArgumentError('Geçerli bir HTTPS veya yerel geliştirme API adresi girin.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKey, normalized);
  }

  Future<String> themeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'system';
  }

  Future<bool> notificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsKey) ?? false;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
  }


  Future<List<int>> scheduledNotificationIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_scheduledNotificationIdsKey) ?? const <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toList(growable: false);
  }

  Future<void> setScheduledNotificationIds(Iterable<int> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scheduledNotificationIdsKey,
      values.map((value) => value.toString()).toList(growable: false),
    );
  }

  Future<void> setThemeMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, value);
  }
}
