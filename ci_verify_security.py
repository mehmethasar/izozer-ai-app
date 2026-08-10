from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SHA_REF = re.compile(r'^[0-9a-f]{40}$')
USES = re.compile(r'^\s*-\s+uses:\s*([^\s#]+)')


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

    encoded_parts = sorted((ROOT / 'parts').glob('part*.b64'))
    if encoded_parts:
        failures.append(f'Eski Base64 kaynak parçaları hâlâ mevcut: {len(encoded_parts)} dosya')
    if (ROOT / 'mobile-source.tar.xz').exists():
        failures.append('Eski mobile-source.tar.xz arşivi hâlâ mevcut.')

    if failures:
        raise SystemExit('Güvenlik doğrulaması başarısız:\n- ' + '\n- '.join(failures))

    print(
        f'Güvenlik doğrulaması başarılı: {len(workflows)} iş akışı, {action_count} sabit action SHA, '
        'sabit üretim API kökeni ve özel bildirim önizlemeleri.'
    )


if __name__ == '__main__':
    main()
