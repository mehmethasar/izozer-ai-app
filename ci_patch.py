from __future__ import annotations

import base64
import plistlib
import re
from pathlib import Path

ROOT = Path('mobile')

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

# flutter_local_notifications, Java zaman API'leri için core-library desugaring gerektirir.
app_build = ROOT / 'android/app/build.gradle.kts'
if app_build.exists():
    text = app_build.read_text(encoding='utf-8')
    if 'isCoreLibraryDesugaringEnabled = true' not in text:
        updated = re.sub(
            r'(compileOptions\s*\{)',
            r'\1\n        isCoreLibraryDesugaringEnabled = true',
            text,
            count=1,
        )
        if updated == text:
            raise SystemExit('Android compileOptions bloğu bulunamadı.')
        text = updated
    desugar_dependency = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
    if desugar_dependency not in text:
        dependencies_match = re.search(r'\ndependencies\s*\{', text)
        if dependencies_match:
            text = re.sub(
                r'(\ndependencies\s*\{)',
                r'\1\n    ' + desugar_dependency,
                text,
                count=1,
            )
        else:
            text += f'\n\ndependencies {{\n    {desugar_dependency}\n}}\n'
    app_build.write_text(text, encoding='utf-8')

print('CI platform uyumluluğu: iOS 15, Android JVM 11 ve desugaring uygulandı.')
