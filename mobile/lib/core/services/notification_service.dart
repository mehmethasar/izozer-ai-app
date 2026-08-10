import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mazdek_ai/core/network/api_client.dart';
import 'package:mazdek_ai/core/services/notification_content.dart';
import 'package:mazdek_ai/core/storage/settings_store.dart';
import 'package:mazdek_ai/models/models.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

final class NotificationService {
  NotificationService({required this._api, required this._settings});
  final ApiClient _api;
  final SettingsStore _settings;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  final StreamController<String> _openController = StreamController<String>.broadcast();
  String? _pendingOpenPayload;
  String? _registeredToken;
  bool _localReady = false;
  bool _firebaseReady = false;

  bool get firebaseReady => _firebaseReady;
  String? get registeredToken => _registeredToken;
  Stream<String> get openEvents => _openController.stream;
  String? consumePendingOpenPayload() {
    final value = _pendingOpenPayload;
    _pendingOpenPayload = null;
    return value;
  }

  void _emitOpen(String payload) {
    if (_openController.hasListener) {
      _openController.add(payload);
    } else {
      _pendingOpenPayload = payload;
    }
  }

  Future<void> initializeLocal() async {
    if (_localReady) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_mazdek'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _local.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _emitOpen(payload);
      },
    );
    final launch = await _local.getNotificationAppLaunchDetails();
    final launchPayload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && launchPayload != null && launchPayload.isNotEmpty) {
      scheduleMicrotask(() => _emitOpen(launchPayload));
    }
    _localReady = true;
  }

  Future<bool> requestPermissions() async {
    await initializeLocal();
    bool granted = true;
    if (Platform.isAndroid) {
      granted = await _local
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          true;
    } else if (Platform.isIOS) {
      granted = await _local
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    await _settings.setNotificationsEnabled(granted);
    if (granted) {
      await scheduleDailySummary();
      await synchronizeOperationalNotifications();
    }
    return granted;
  }

  Future<void> initializeRemote() async {
    if (_firebaseReady) return;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true, provisional: false);
      await _registerSafely(await messaging.getToken());
      _tokenSubscription = messaging.onTokenRefresh.listen(_registerSafely);
      _messageSubscription = FirebaseMessaging.onMessage.listen((message) async {
        final payload = message.data['type']?.toString() ?? message.data['payload']?.toString();
        await _showNow(
          NotificationContent.privateTitle(payload),
          NotificationContent.privateBody,
          payload: payload,
        );
      });
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final payload = message.data['type']?.toString() ?? message.data['payload']?.toString();
        if (payload != null && payload.isNotEmpty) _emitOpen(payload);
      });
      final initial = await messaging.getInitialMessage();
      final initialPayload = initial?.data['type']?.toString() ?? initial?.data['payload']?.toString();
      if (initialPayload != null && initialPayload.isNotEmpty) scheduleMicrotask(() => _emitOpen(initialPayload));
      _firebaseReady = true;
    } catch (_) {
      _firebaseReady = false;
    }
  }

  Future<void> _registerSafely(String? token) async {
    if (token == null || token.isEmpty) return;
    _registeredToken = token;
    try {
      await _api.registerDeviceToken(
        token,
        provider: 'fcm',
        platform: Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : 'unknown',
        environment: const bool.fromEnvironment('dart.vm.product') ? 'production' : 'sandbox',
      );
    } catch (_) {
      // Firebase kullanılabilir kalsın; sunucu bağlantısı geri geldiğinde uygulama yeniden kaydeder.
    }
  }

  Future<void> _showNow(String title, String body, {String? payload}) async {
    await initializeLocal();
    await _local.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'mazdek_finance',
          'Mazdek Finans ve Görev Bildirimleri',
          channelDescription: 'Finansal vadeler, görevler ve günlük yönetim raporları.',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.secret,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: payload,
    );
  }

  Future<void> scheduleDailySummary({int hour = 19, int minute = 0}) async {
    await initializeLocal();
    if (!await _settings.notificationsEnabled()) return;
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    await _local.zonedSchedule(
      id: 1900,
      title: NotificationContent.privateTitle('daily_report'),
      body: NotificationContent.privateBody,
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'mazdek_daily',
          'Günlük Yönetim Raporu',
          channelDescription: 'Her gün Mazdek yönetim özeti.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          visibility: NotificationVisibility.secret,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_report',
    );
  }

  Future<void> synchronizeOperationalNotifications() async {
    await initializeLocal();
    if (!await _settings.notificationsEnabled()) return;
    final previousIds = await _settings.scheduledNotificationIds();
    for (final id in previousIds) {
      await _local.cancel(id: id);
    }

    final records = <({String kind, EntityRecord item})>[];
    Future<void> collect(String endpoint, String kind) async {
      try {
        final result = await _api.records(endpoint);
        records.addAll(result.data.map((item) => (kind: kind, item: item)));
      } catch (_) {
        // Bir modül ulaşılamazsa diğer bildirimlerin kurulmasını engelleme.
      }
    }

    await Future.wait([
      collect('/api/reminders?status=scheduled', 'reminder'),
      collect('/api/tasks', 'task'),
      collect('/api/invoices', 'invoice'),
    ]);

    final now = tz.TZDateTime.now(tz.local);
    final candidates = <({int id, tz.TZDateTime at, String title, String body, String payload})>[];
    for (final record in records) {
      final raw = record.item.raw;
      if (raw['active'] == false || raw['archivedAt'] != null) continue;
      if (record.kind == 'task' && '${raw['status']}' == 'completed') continue;
      if (record.kind == 'invoice' && '${raw['status']}' == 'paid') continue;
      final source = record.kind == 'reminder' ? raw['dueAt'] : raw['dueDate'];
      final at = _notificationDate(source?.toString(), record.kind);
      if (at == null || !at.isAfter(now) || at.difference(now) > const Duration(days: 60)) continue;
      final id = _stableId('${record.kind}:${record.item.id}');
      final title = NotificationContent.privateTitle(record.kind);
      const body = NotificationContent.privateBody;
      candidates.add((id: id, at: at, title: title, body: body, payload: '${record.kind}:${record.item.id}'));
    }
    candidates.sort((a, b) => a.at.compareTo(b.at));

    final scheduled = <int>[];
    for (final item in candidates.take(40)) {
      await _local.zonedSchedule(
        id: item.id,
        title: item.title,
        body: item.body,
        scheduledDate: item.at,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'mazdek_operational',
            'Görev ve Finans Vadeleri',
            channelDescription: 'Görev, hatırlatma, ödeme ve tahsilat vadeleri.',
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.secret,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: item.payload,
      );
      scheduled.add(item.id);
    }
    await _settings.setScheduledNotificationIds(scheduled);
  }

  tz.TZDateTime? _notificationDate(String? value, String kind) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        final parts = value.split('-').map(int.parse).toList(growable: false);
        final hour = kind == 'invoice' ? 9 : 8;
        return tz.TZDateTime(tz.local, parts[0], parts[1], parts[2], hour);
      }
      return tz.TZDateTime.from(DateTime.parse(value), tz.local);
    } catch (_) {
      return null;
    }
  }

  int _stableId(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return 20000 + hash.remainder(2000000000);
  }

  Future<void> disable() async {
    await _settings.setNotificationsEnabled(false);
    await _local.cancelAll();
    await _settings.setScheduledNotificationIds(const []);
    if (_registeredToken != null) {
      try { await _api.unregisterDeviceToken(_registeredToken!); } catch (_) {}
    }
    _registeredToken = null;
  }

  Future<void> disposeForLogout() async {
    if (_registeredToken != null) {
      try { await _api.unregisterDeviceToken(_registeredToken!); } catch (_) {}
    }
    _registeredToken = null;
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
    _tokenSubscription = null;
    _messageSubscription = null;
    _openedSubscription = null;
    _firebaseReady = false;
    await _local.cancelAll();
    await _settings.setScheduledNotificationIds(const []);
  }

  Future<void> shutdown() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
    if (!_openController.isClosed) await _openController.close();
  }
}
