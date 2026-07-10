import 'package:firebase_messaging/firebase_messaging.dart';

/// A received push notification, in the app's own shape (never a Firebase
/// `RemoteMessage`), so ViewModels/Views stay decoupled and testable.
class AppNotification {
  const AppNotification({
    required this.title,
    required this.body,
    required this.receivedAt,
  });

  final String title;
  final String body;
  final DateTime receivedAt;

  factory AppNotification.fromRemote(RemoteMessage message) {
    final n = message.notification;
    return AppNotification(
      title: n?.title ?? message.data['title'] as String? ?? 'Notification',
      body: n?.body ?? message.data['body'] as String? ?? '',
      receivedAt: message.sentTime ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'receivedAt': receivedAt.toIso8601String(),
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        receivedAt:
            DateTime.tryParse(json['receivedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Contract for Firebase Cloud Messaging (Lab 03 task 9.3). ViewModels depend on
/// this, never on `firebase_messaging` directly.
abstract interface class MessagingApi {
  /// Requests notification permission and returns the device FCM token.
  Future<String?> initialize();

  /// Foreground push messages, mapped to [AppNotification].
  Stream<AppNotification> get onMessage;

  /// The message (if any) that launched the app from a terminated state by the
  /// user tapping a notification.
  Future<AppNotification?> initialMessage();
}

/// Firebase-backed [MessagingApi]. [FirebaseMessaging.instance] is resolved
/// lazily so constructing this never requires Firebase.
class MessagingService implements MessagingApi {
  MessagingService({FirebaseMessaging? messaging}) : _injected = messaging;

  final FirebaseMessaging? _injected;
  FirebaseMessaging get _messaging => _injected ?? FirebaseMessaging.instance;

  @override
  Future<String?> initialize() async {
    await _messaging.requestPermission();
    return _messaging.getToken();
  }

  @override
  Stream<AppNotification> get onMessage =>
      FirebaseMessaging.onMessage.map(AppNotification.fromRemote);

  @override
  Future<AppNotification?> initialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : AppNotification.fromRemote(message);
  }
}
