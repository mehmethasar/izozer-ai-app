from __future__ import annotations

import re
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SHA_REF = re.compile(r'^[0-9a-f]{40}$')
USES = re.compile(r'^\s*-\s+uses:\s*([^\s#]+)')
PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'


def validate_app_icon(failures: list[str]) -> None:
    icon_path = ROOT / 'mobile' / 'assets' / 'branding' / 'app_icon.png'
    if not icon_path.is_file():
        failures.append('Üretim uygulama simgesi bulunamadı: mobile/assets/branding/app_icon.png')
        return

    data = icon_path.read_bytes()
    if len(data) < 29 or data[:8] != PNG_SIGNATURE or data[12:16] != b'IHDR':
        failures.append('Uygulama simgesi geçerli bir PNG dosyası değil.')
        return

    width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(
        '>IIBBBBB', data[16:29]
    )
    if (width, height) != (1024, 1024):
        failures.append(
            f'Uygulama simgesi 1024x1024 olmalı; bulunan boyut: {width}x{height}.'
        )
    if bit_depth != 8 or color_type != 2:
        failures.append(
            'Uygulama simgesi 8 bit, şeffaflıksız RGB PNG olmalı; '
            f'bit derinliği={bit_depth}, renk türü={color_type}.'
        )
    if compression != 0 or filtering != 0 or interlace not in (0, 1):
        failures.append('Uygulama simgesinin PNG başlığı desteklenmeyen değerler içeriyor.')


def main() -> None:
    failures: list[str] = []
    action_count = 0

    workflows = sorted((ROOT / '.github' / 'workflows').glob('*.yml'))
    if not workflows:
        failures.append('GitHub Actions iş akışı bulunamadı.')

    for workflow in workflows:
        for line_number, line in enumerate(workflow.read_text(encoding='utf-8').splitlines(), start=1):
            match = USES.match(line)
            if match is None:
                continue
            action = match.group(1)
            if action.startswith('./'):
                continue
            action_count += 1
            if '@' not in action:
                failures.append(f'{workflow.relative_to(ROOT)}:{line_number}: action referansı eksik')
                continue
            _, reference = action.rsplit('@', 1)
            if SHA_REF.fullmatch(reference) is None:
                failures.append(
                    f'{workflow.relative_to(ROOT)}:{line_number}: action tam commit SHA ile sabitlenmemiş: {action}'
                )

    config_path = ROOT / 'mobile' / 'lib' / 'core' / 'config' / 'app_config.dart'
    if not config_path.is_file():
        failures.append('Doğrudan Flutter kaynağı bulunamadı: mobile/lib/core/config/app_config.dart')
    else:
        config = config_path.read_text(encoding='utf-8')
        required_config = (
            "static const String productionApiUrl = 'https://api.izozer.com';",
            "static const String productionApiHost = 'api.izozer.com';",
            'static const bool allowsCustomApiUrl = !kReleaseMode;',
        )
        for expected in required_config:
            if expected not in config:
                failures.append(f'Üretim API güvenlik politikası eksik: {expected}')

    source_guards = {
        'mobile/lib/core/storage/settings_store.dart': (
            'if (!AppConfig.allowsCustomApiUrl) return AppConfig.productionApiUrl;',
            "throw UnsupportedError('Yayın sürümünde API adresi değiştirilemez.');",
            'return prefs.getBool(_notificationsKey) ?? false;',
        ),
        'mobile/lib/screens/login_screen.dart': (
            'if (AppConfig.allowsCustomApiUrl) {',
            "title: const Text('Geliştirme sunucusu')",
        ),
        'mobile/lib/screens/settings_screen.dart': (
            'if (AppConfig.allowsCustomApiUrl) ...[',
            'snap.data ?? false',
        ),
        'mobile/lib/core/services/notification_service.dart': (
            'NotificationContent.privateTitle',
            'NotificationContent.privateBody',
        ),
    }
    for relative_path, expected_values in source_guards.items():
        path = ROOT / relative_path
        if not path.is_file():
            failures.append(f'Güvenlik kontrolü için gerekli kaynak eksik: {relative_path}')
            continue
        text = path.read_text(encoding='utf-8')
        for expected in expected_values:
            if expected not in text:
                failures.append(f'{relative_path} güvenlik koruması eksik: {expected}')

    notification_service = ROOT / 'mobile/lib/core/services/notification_service.dart'
    if notification_service.is_file():
        visibility_count = notification_service.read_text(encoding='utf-8').count(
            'visibility: NotificationVisibility.secret'
        )
        if visibility_count < 3:
            failures.append(
                f'Android kilit ekranı için 3 gizli bildirim politikası bekleniyordu, bulunan: {visibility_count}'
            )

    pubspec = ROOT / 'mobile' / 'pubspec.yaml'
    if not pubspec.is_file() or 'http: 1.6.0' not in pubspec.read_text(encoding='utf-8'):
        failures.append('mobile/pubspec.yaml içinde sabit http 1.6.0 bağımlılığı bulunamadı.')

    validate_app_icon(failures)

    encoded_parts = sorted((ROOT / 'parts').glob('part*.b64'))
    if encoded_parts:
        failures.append(f'Eski Base64 kaynak parçaları hâlâ mevcut: {len(encoded_parts)} dosya')
    if (ROOT / 'mobile-source.tar.xz').exists():
        failures.append('Eski mobile-source.tar.xz arşivi hâlâ mevcut.')

    if failures:
        raise SystemExit('Güvenlik doğrulaması başarısız:\n- ' + '\n- '.join(failures))

    print(
        f'Güvenlik doğrulaması başarılı: {len(workflows)} iş akışı, {action_count} sabit action SHA, '
        'sabit üretim API kökeni, özel bildirim önizlemeleri ve 1024x1024 üretim simgesi.'
    )


if __name__ == '__main__':
    main()
