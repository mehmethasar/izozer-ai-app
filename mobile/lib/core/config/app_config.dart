import 'package:flutter/foundation.dart';

final class AppConfig {
  const AppConfig._();

  static const String appName = 'Mazdek';
  static const String productionApiUrl = 'https://api.izozer.com';
  static const String productionApiHost = 'api.izozer.com';
  static const bool allowsCustomApiUrl = !kReleaseMode;
  static const String defaultApiUrl = kReleaseMode
      ? productionApiUrl
      : String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://10.0.2.2:8787',
        );
  static const String appleServiceId = String.fromEnvironment('APPLE_SERVICE_ID');
  static const String appleRedirectUri = String.fromEnvironment('APPLE_REDIRECT_URI');

  static bool isSecureApiUrl(String value, {bool? releaseMode}) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) return false;
    if (uri.path.isNotEmpty && uri.path != '/') return false;

    final release = releaseMode ?? kReleaseMode;
    if (release) {
      return uri.scheme == 'https' &&
          uri.host.toLowerCase() == productionApiHost &&
          (!uri.hasPort || uri.port == 443);
    }

    final localHost = uri.host == '127.0.0.1' || uri.host == 'localhost' || uri.host == '10.0.2.2';
    return uri.scheme == 'https' || (uri.scheme == 'http' && localHost);
  }
}
