final class NotificationContent {
  const NotificationContent._();

  static const String privateBody = 'Ayrıntıları görüntülemek için Mazdek\'i açın.';

  static String privateTitle(String? payloadType) {
    final kind = payloadType?.split(':').first;
    return switch (kind) {
      'daily_report' => 'Mazdek günlük özeti',
      'invoice' => 'Mazdek finans hatırlatması',
      'task' => 'Mazdek görev hatırlatması',
      'reminder' => 'Mazdek hatırlatması',
      _ => 'Yeni Mazdek bildirimi',
    };
  }
}
