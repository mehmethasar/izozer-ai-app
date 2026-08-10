import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mazdek_ai/app/mazdek_app.dart';
import 'package:mazdek_ai/core/network/api_client.dart';
import 'package:mazdek_ai/core/services/biometric_service.dart';
import 'package:mazdek_ai/core/services/notification_service.dart';
import 'package:mazdek_ai/core/storage/offline_cache.dart';
import 'package:mazdek_ai/core/storage/settings_store.dart';
import 'package:mazdek_ai/core/storage/token_store.dart';
import 'package:mazdek_ai/state/app_state.dart';

@pragma('vm:entry-point')
Future<void> mazdekFirebaseBackgroundHandler(RemoteMessage _) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase istemci dosyaları henüz bağlanmadıysa bildirim sistemi sessizce atlanır.
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(mazdekFirebaseBackgroundHandler);
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  final tokens = TokenStore(secureStorage);
  final settings = SettingsStore();
  final api = ApiClient(tokens: tokens, settings: settings, cache: OfflineCache(secureStorage));
  final notifications = NotificationService(api: api, settings: settings);
  final state = AppState(
    api: api,
    tokens: tokens,
    settings: settings,
    biometrics: BiometricService(LocalAuthentication()),
    notifications: notifications,
  );
  await state.initialize();
  runApp(MazdekApp(state: state));
}
