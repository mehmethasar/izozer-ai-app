from __future__ import annotations

import base64
import plistlib
import re
from pathlib import Path

ROOT = Path('mobile')


def replace(path: str, old: str, new: str) -> None:
    target = ROOT / path
    text = target.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'Beklenen kaynak parçası bulunamadı: {path}: {old[:80]!r}')
    target.write_text(text.replace(old, new), encoding='utf-8')


replace(
    'lib/core/network/api_client.dart',
    "  ApiClient({required TokenStore tokens, required SettingsStore settings, required OfflineCache cache, http.Client? httpClient}) : _tokens = tokens, _settings = settings, _cache = cache, _http = httpClient ?? http.Client();",
    "  ApiClient({required this._tokens, required this._settings, required this._cache, http.Client? httpClient}) : _http = httpClient ?? http.Client();",
)
replace(
    'lib/core/network/api_client.dart',
    "  Future<AuthResponse> appleLogin({required String identityToken, required String nonce, String? authorizationCode, String? name}) async {\n    final json = await _requestJson('/api/auth/apple', method: 'POST', body: {'identityToken': identityToken, 'nonce': nonce, if (authorizationCode != null) 'authorizationCode': authorizationCode, if (name != null) 'name': name}, authenticated: false, cache: false);\n    return AuthResponse.fromJson(json as Map<String, dynamic>);\n  }",
    "  Future<AuthResponse> appleLogin({required String identityToken, required String nonce, String? authorizationCode, String? name}) async {\n    final body = <String, dynamic>{'identityToken': identityToken, 'nonce': nonce};\n    if (authorizationCode != null) body['authorizationCode'] = authorizationCode;\n    if (name != null) body['name'] = name;\n    final json = await _requestJson('/api/auth/apple', method: 'POST', body: body, authenticated: false, cache: false);\n    return AuthResponse.fromJson(json as Map<String, dynamic>);\n  }",
)
replace(
    'lib/core/network/api_client.dart',
    "    Future<http.StreamedResponse> build() async {",
    "    Future<http.BaseRequest> build() async {",
)
replace(
    'lib/core/services/notification_service.dart',
    "  NotificationService({required ApiClient api, required SettingsStore settings}) : _api = api, _settings = settings;",
    "  NotificationService({required this._api, required this._settings});",
)
replace(
    'lib/core/services/notification_service.dart',
    "  String? consumePendingOpenPayload() { final value = _pendingOpenPayload; _pendingOpenPayload = null; return value; }\n  void _emitOpen(String payload) { if (_openController.hasListener) _openController.add(payload); else _pendingOpenPayload = payload; }",
    "  String? consumePendingOpenPayload() {\n    final value = _pendingOpenPayload;\n    _pendingOpenPayload = null;\n    return value;\n  }\n\n  void _emitOpen(String payload) {\n    if (_openController.hasListener) {\n      _openController.add(payload);\n    } else {\n      _pendingOpenPayload = payload;\n    }\n  }",
)
replace(
    'lib/screens/account_privacy_screen.dart',
    "  Future<void> deleteAccount() async {\n    final password = TextEditingController();",
    "  Future<void> deleteAccount() async {\n    final appState = AppScope.of(context);\n    final password = TextEditingController();",
)
replace(
    'lib/screens/account_privacy_screen.dart',
    "    try {\n      await AppScope.of(context).api.deleteAccount(currentPassword: password.text, confirmation: confirmation.text);\n      if (mounted) await AppScope.of(context).logout();",
    "    try {\n      await appState.api.deleteAccount(currentPassword: password.text, confirmation: confirmation.text);\n      if (mounted) await appState.logout();",
)
replace(
    'lib/screens/settings_screen.dart',
    "onChanged: busy ? null : (v) async { try { await state.setBiometric(v); setState(() {}); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); } }",
    "onChanged: busy ? null : (v) async { final messenger = ScaffoldMessenger.of(context); try { await state.setBiometric(v); if (mounted) setState(() {}); } catch (e) { if (mounted) messenger.showSnackBar(SnackBar(content: Text(e.toString()))); } }",
)
replace(
    'lib/screens/shell_screen.dart',
    "                      if (mounted) {\n                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sunucu bağlantısı henüz kurulamadı.')));\n                      }",
    "                      if (context.mounted) {\n                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sunucu bağlantısı henüz kurulamadı.')));\n                      }",
)
replace(
    'lib/screens/integration_settings_screen.dart',
    "DropdownButtonFormField<String>(value: apnsEnvironment,",
    "DropdownButtonFormField<String>(initialValue: apnsEnvironment,",
)
replace(
    'lib/screens/chat_screen.dart',
    "import 'package:cross_file/cross_file.dart';\n",
    "",
)

widget_test = ROOT / 'test/widget_test.dart'
if widget_test.exists():
    widget_test.unlink()

asset = ROOT / 'assets/branding/app_icon.png'
asset.parent.mkdir(parents=True, exist_ok=True)
if not asset.exists():
    asset.write_bytes(base64.b64decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2S6sAAAAASUVORK5CYII='
    ))

# Firebase Core/Messaging 4.x, iOS 15 veya üzerini gerektiriyor.
project = ROOT / 'ios/Runner.xcodeproj/project.pbxproj'
if project.exists():
    text = project.read_text(encoding='utf-8')
    text = re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;', 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;', text)
    project.write_text(text, encoding='utf-8')

framework_info = ROOT / 'ios/Flutter/AppFrameworkInfo.plist'
if framework_info.exists():
    with framework_info.open('rb') as handle:
        data = plistlib.load(handle)
    data['MinimumOSVersion'] = '15.0'
    with framework_info.open('wb') as handle:
        plistlib.dump(data, handle, sort_keys=False)

podfile = ROOT / 'ios/Podfile'
if podfile.exists():
    text = podfile.read_text(encoding='utf-8')
    if re.search(r"platform :ios, '[^']+'", text):
        text = re.sub(r"platform :ios, '[^']+'", "platform :ios, '15.0'", text)
    else:
        text = "platform :ios, '15.0'\n" + text
    podfile.write_text(text, encoding='utf-8')

# Eski Flutter eklentilerinin Java 11 / Kotlin 1.8 hedef çakışmasını gider.
android_build = ROOT / 'android/build.gradle.kts'
if android_build.exists():
    text = android_build.read_text(encoding='utf-8')
    marker = '// Mazdek AI: align plugin Kotlin tasks with Java 11'
    if marker not in text:
        text += f'''\n\n{marker}\nsubprojects {{\n    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {{\n        compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)\n    }}\n}}\n'''
    android_build.write_text(text, encoding='utf-8')

gradle_properties = ROOT / 'android/gradle.properties'
if gradle_properties.exists():
    text = gradle_properties.read_text(encoding='utf-8')
    if 'kotlin.jvm.target.validation.mode=warning' not in text:
        text += '\nkotlin.jvm.target.validation.mode=warning\n'
    gradle_properties.write_text(text, encoding='utf-8')

print('CI Flutter kaynak düzeltmeleri, iOS 15 ve Android JVM 11 hedefi uygulandı.')
