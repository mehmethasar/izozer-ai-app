import 'package:flutter_test/flutter_test.dart';
import 'package:mazdek_ai/core/config/app_config.dart';
import 'package:mazdek_ai/core/services/notification_content.dart';

void main() {
  group('production API origin policy', () {
    test('accepts only the Mazdek production origin', () {
      expect(AppConfig.isSecureApiUrl('https://api.izozer.com', releaseMode: true), isTrue);
      expect(AppConfig.isSecureApiUrl('https://api.izozer.com/', releaseMode: true), isTrue);
      expect(AppConfig.isSecureApiUrl('https://api.izozer.com:443', releaseMode: true), isTrue);
    });

    test('rejects alternate or ambiguous production destinations', () {
      const rejected = [
        'http://api.izozer.com',
        'https://evil.example',
        'https://api.izozer.com.evil.example',
        'https://api.izozer.com@evil.example',
        'https://api.izozer.com:444',
        'https://api.izozer.com/api',
        'https://api.izozer.com?next=https://evil.example',
        'https://api.izozer.com#evil',
      ];

      for (final value in rejected) {
        expect(AppConfig.isSecureApiUrl(value, releaseMode: true), isFalse, reason: value);
      }
    });
  });

  test('notification previews contain no record-specific data', () {
    expect(NotificationContent.privateTitle('invoice:invoice-42'), 'Mazdek finans hatırlatması');
    expect(NotificationContent.privateTitle('task:task-7'), 'Mazdek görev hatırlatması');
    expect(NotificationContent.privateBody, 'Ayrıntıları görüntülemek için Mazdek\'i açın.');
    expect(NotificationContent.privateBody, isNot(contains('12.500')));
    expect(NotificationContent.privateBody, isNot(contains('Cari')));
  });
}
