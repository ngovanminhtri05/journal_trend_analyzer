import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'messaging_service.dart';

/// Shows a system notification banner while the app is in the foreground
/// (FCM does not display foreground messages on its own). ViewModels depend on
/// this interface, never on the plugin, so they stay testable.
abstract interface class LocalNotifierApi {
  Future<void> initialize();
  Future<void> show(AppNotification notification);
}

/// flutter_local_notifications-backed implementation.
class LocalNotifier implements LocalNotifierApi {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notifications',
    description: 'Journal Trend Analyzer notifications',
    importance: Importance.high,
  );

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    _initialized = true;
  }

  @override
  Future<void> show(AppNotification notification) async {
    if (!_initialized) await initialize();
    await _plugin.show(
      // A per-notification id so multiple banners stack.
      id: notification.receivedAt.millisecondsSinceEpoch ~/ 1000,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}

/// No-op for tests / contexts without a platform plugin.
class NoopLocalNotifier implements LocalNotifierApi {
  const NoopLocalNotifier();
  @override
  Future<void> initialize() async {}
  @override
  Future<void> show(AppNotification notification) async {}
}
