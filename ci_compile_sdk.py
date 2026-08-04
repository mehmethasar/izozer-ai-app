from __future__ import annotations

import re
from pathlib import Path

PUB_CACHE = Path.home() / '.pub-cache' / 'hosted' / 'pub.dev'
if not PUB_CACHE.exists():
    raise SystemExit(f'Pub önbelleği bulunamadı: {PUB_CACHE}')

changed: list[str] = []
patterns = (
    (re.compile(r'compileSdkVersion\s*=\s*\d+'), 'compileSdkVersion = 36'),
    (re.compile(r'compileSdkVersion\s+\d+'), 'compileSdkVersion 36'),
    (re.compile(r'compileSdk\s*=\s*\d+'), 'compileSdk = 36'),
    (re.compile(r'compileSdk\s+\d+'), 'compileSdk 36'),
)

for build_file in sorted(PUB_CACHE.glob('*/android/build.gradle*')):
    text = build_file.read_text(encoding='utf-8')
    updated = text
    for pattern, replacement in patterns:
        updated = pattern.sub(replacement, updated)
    if updated != text:
        build_file.write_text(updated, encoding='utf-8')
        changed.append(str(build_file))

if not changed:
    raise SystemExit('API 36 seviyesine yükseltilecek Android eklenti build dosyası bulunamadı.')

print(f'{len(changed)} Android eklenti modülü compileSdk 36 seviyesine getirildi:')
for path in changed:
    print(f' - {path}')
