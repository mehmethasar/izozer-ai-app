from __future__ import annotations

import plistlib
import re
from pathlib import Path

ROOT = Path('mobile')
API_URL = 'https://izozer.com'
APPLE_REDIRECT = f'{API_URL}/auth/apple/callback'
APP_NAME = 'Mazdek'
BUNDLE_ID = 'com.mazdek.mazdekai'


def rewrite_text(path: str, transform) -> None:
    target = ROOT / path
    if not target.exists():
        return
    original = target.read_text(encoding='utf-8')
    updated = transform(original)
    if updated != original:
        target.write_text(updated, encoding='utf-8')


def configure_app_config(text: str) -> str:
    text = re.sub(r"static const String appName = '[^']*';", "static const String appName = 'Mazdek';", text)
    text = re.sub(
        r"defaultValue: kReleaseMode \? '[^']*' : 'http://10\.0\.2\.2:8787',",
        "defaultValue: kReleaseMode ? 'https://izozer.com' : 'http://10.0.2.2:8787',",
        text,
    )
    return text


rewrite_text('lib/core/config/app_config.dart', configure_app_config)
rewrite_text(
    'lib/screens/login_screen.dart',
    lambda text: text
    .replace("'Mazdek AI Yönetim',", "'Mazdek',")
    .replace("'Mazdek AI',", "'Mazdek',")
    .replace("hintText: 'https://api.sirketiniz.com',", "hintText: 'https://izozer.com',")
    .replace("hintText: 'https://api.izozer.com',", "hintText: 'https://izozer.com',"),
)
rewrite_text('store/app-store/tr-TR/name.txt', lambda _text: 'Mazdek\n')
rewrite_text('fastlane/metadata/android/tr-TR/title.txt', lambda _text: 'Mazdek\n')
rewrite_text(
    '.env.build.example',
    lambda text: re.sub(r'^API_BASE_URL=.*$', f'API_BASE_URL={API_URL}', text, flags=re.MULTILINE)
    .replace('https://api.sirketiniz.com/auth/apple/callback', APPLE_REDIRECT)
    .replace('https://api.izozer.com/auth/apple/callback', APPLE_REDIRECT),
)

# Kullanıcıya görünen eski marka ifadelerini yalnızca mobil kaynaklarda sadeleştir.
for target in ROOT.rglob('*'):
    if not target.is_file() or target.suffix.lower() not in {'.dart', '.txt', '.md', '.yaml', '.yml', '.plist', '.xml'}:
        continue
    try:
        text = target.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        continue
    updated = text.replace('https://api.izozer.com', API_URL).replace('Mazdek AI Yönetim', APP_NAME).replace('Mazdek AI', APP_NAME)
    if updated != text:
        target.write_text(updated, encoding='utf-8')

# Android görünen ad, namespace ve applicationId.
manifest = ROOT / 'android/app/src/main/AndroidManifest.xml'
if manifest.exists():
    text = manifest.read_text(encoding='utf-8')
    text = re.sub(r'android:label="[^"]*"', 'android:label="Mazdek"', text, count=1)
    manifest.write_text(text, encoding='utf-8')

android_app_build = ROOT / 'android/app/build.gradle.kts'
if android_app_build.exists():
    text = android_app_build.read_text(encoding='utf-8')
    text = re.sub(r'namespace\s*=\s*"[^"]+"', f'namespace = "{BUNDLE_ID}"', text)
    text = re.sub(r'applicationId\s*=\s*"[^"]+"', f'applicationId = "{BUNDLE_ID}"', text)
    android_app_build.write_text(text, encoding='utf-8')

# Flutter'ın oluşturduğu MainActivity paketini kesin uygulama kimliğiyle eşleştir.
for activity in ROOT.glob('android/app/src/main/kotlin/**/MainActivity.kt'):
    text = activity.read_text(encoding='utf-8')
    text = re.sub(r'^package\s+[\w.]+', f'package {BUNDLE_ID}', text, count=1, flags=re.MULTILINE)
    activity.write_text(text, encoding='utf-8')

# iOS görünen ad ve kesin Bundle ID.
info = ROOT / 'ios/Runner/Info.plist'
if info.exists():
    with info.open('rb') as handle:
        data = plistlib.load(handle)
    data['CFBundleDisplayName'] = APP_NAME
    data['CFBundleName'] = APP_NAME
    with info.open('wb') as handle:
        plistlib.dump(data, handle, sort_keys=False)

xcode_project = ROOT / 'ios/Runner.xcodeproj/project.pbxproj'
if xcode_project.exists():
    text = xcode_project.read_text(encoding='utf-8')
    text = re.sub(r'PRODUCT_BUNDLE_IDENTIFIER = com\.mazdek\.[^;]+;', f'PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};', text)
    text = re.sub(r'PRODUCT_BUNDLE_IDENTIFIER = "?com\.mazdek\.[^;]+\.RunnerTests"?;', f'PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}.RunnerTests;', text)
    xcode_project.write_text(text, encoding='utf-8')

print(
    f'Uygulama adı {APP_NAME}; Android/iOS kimliği {BUNDLE_ID}; '
    f'canlı API {API_URL}; Apple dönüşü {APPLE_REDIRECT} olarak yapılandırıldı.'
)
