from __future__ import annotations

import plistlib
import re
from pathlib import Path

ROOT = Path('mobile')
API_URL = 'https://api.izozer.com'
APPLE_REDIRECT = f'{API_URL}/auth/apple/callback'
APP_NAME = 'Mazdek'


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
        "defaultValue: kReleaseMode ? 'https://api.izozer.com' : 'http://10.0.2.2:8787',",
        text,
    )
    return text


rewrite_text('lib/core/config/app_config.dart', configure_app_config)
rewrite_text('lib/screens/login_screen.dart', lambda text: text.replace("'Mazdek AI Yönetim',", "'Mazdek',").replace("hintText: 'https://api.sirketiniz.com',", "hintText: 'https://api.izozer.com',"))
rewrite_text('store/app-store/tr-TR/name.txt', lambda _text: 'Mazdek\n')
rewrite_text('fastlane/metadata/android/tr-TR/title.txt', lambda _text: 'Mazdek\n')
rewrite_text('.env.build.example', lambda text: re.sub(r'^API_BASE_URL=.*$', f'API_BASE_URL={API_URL}', text, flags=re.MULTILINE).replace('https://api.sirketiniz.com/auth/apple/callback', APPLE_REDIRECT))

manifest = ROOT / 'android/app/src/main/AndroidManifest.xml'
if manifest.exists():
    text = manifest.read_text(encoding='utf-8')
    text = re.sub(r'android:label="[^"]*"', 'android:label="Mazdek"', text, count=1)
    manifest.write_text(text, encoding='utf-8')

info = ROOT / 'ios/Runner/Info.plist'
if info.exists():
    with info.open('rb') as handle:
        data = plistlib.load(handle)
    data['CFBundleDisplayName'] = APP_NAME
    data['CFBundleName'] = APP_NAME
    with info.open('wb') as handle:
        plistlib.dump(data, handle, sort_keys=False)

print(f'Uygulama adı {APP_NAME}; canlı API {API_URL}; Apple dönüşü {APPLE_REDIRECT} olarak yapılandırıldı.')
