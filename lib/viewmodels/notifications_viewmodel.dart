import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/local_notifier.dart';
import '../firebase/messaging_service.dart';

/// Notification Center (Lab 03 task 8.2).
///
/// Keeps a local, persisted list of received FCM messages and the device token.
/// Coverage of the three delivery cases:
/// - **foreground**: [MessagingApi.onMessage] → added to the list AND shown as a
///   banner via [LocalNotifierApi] (FCM does not surface foreground messages);
/// - **background/terminated, tapped**: [MessagingApi.onMessageOpenedApp] /
///   [MessagingApi.initialMessage] → added to the list on open;
/// - **background data messages**: persisted from the background isolate via
///   [persistIncoming], then reloaded on next [load].
///
/// No Firebase types leak in — it is unit-testable with fakes.
class NotificationsViewModel extends ChangeNotifier {
  NotificationsViewModel(
    this._messaging, {
    SharedPreferences? prefs,
    LocalNotifierApi? notifier,
  }) : _prefs = prefs,
       _notifier = notifier;

  static const String storageKey = 'notifications_v1';
  static const int maxStored = 50;

  final MessagingApi _messaging;
  final LocalNotifierApi? _notifier;
  SharedPreferences? _prefs;
  StreamSubscription<AppNotification>? _foregroundSub;
  StreamSubscription<AppNotification>? _openedSub;

  final List<AppNotification> _items = [];
  List<AppNotification> get notifications => List.unmodifiable(_items);

  /// The device FCM token, once resolved (for display / targeting a test push).
  String? token;

  Future<SharedPreferences> get _preferences async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Loads persisted notifications (incl. any saved by the background isolate),
  /// wires the delivery streams, and requests permission + the FCM token.
  Future<void> load() async {
    final prefs = await _preferences;
    _items
      ..clear()
      ..addAll(_decodeAll(prefs.getStringList(storageKey) ?? const []));
    notifyListeners();

    // Foreground: add + show a banner. Subscribe only after the persisted list
    // is in place so an incoming message can't be clobbered by the load.
    _foregroundSub ??= _messaging.onMessage.listen((n) {
      _notifier?.show(n);
      add(n);
    });
    // Tapped from background: add (the OS already showed the banner).
    _openedSub ??= _messaging.onMessageOpenedApp.listen(add);
    // Launched from terminated by a tap.
    final initial = await _messaging.initialMessage();
    if (initial != null) add(initial);

    try {
      await _notifier?.initialize();
      token = await _messaging.initialize();
      notifyListeners();
    } catch (_) {
      // Permission denied / no Play Services — leave token null.
    }
  }

  /// Adds a received notification to the front of the list and persists it.
  /// De-dupes against the current head (the same message can arrive via more
  /// than one path — e.g. background-persist + tap-to-open).
  void add(AppNotification notification) {
    if (_items.isNotEmpty) {
      final head = _items.first;
      if (head.title == notification.title &&
          head.body == notification.body &&
          head.receivedAt == notification.receivedAt) {
        return;
      }
    }
    _items.insert(0, notification);
    if (_items.length > maxStored) {
      _items.removeRange(maxStored, _items.length);
    }
    _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _items.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await _preferences;
    await prefs.setStringList(
      storageKey,
      _items.map((n) => jsonEncode(n.toJson())).toList(),
    );
  }

  static List<AppNotification> _decodeAll(List<String> raw) => raw
      .map(
        (s) => AppNotification.fromJson(jsonDecode(s) as Map<String, dynamic>),
      )
      .toList();

  /// Persists an incoming notification from any isolate (used by the FCM
  /// background handler). Reads the same store, prepends, caps, and writes back.
  static Future<void> persistIncoming(AppNotification notification) async {
    final prefs = await SharedPreferences.getInstance();
    final items = _decodeAll(prefs.getStringList(storageKey) ?? const [])
      ..insert(0, notification);
    if (items.length > maxStored) items.removeRange(maxStored, items.length);
    await prefs.setStringList(
      storageKey,
      items.map((n) => jsonEncode(n.toJson())).toList(),
    );
  }

  @override
  void dispose() {
    _foregroundSub?.cancel();
    _openedSub?.cancel();
    super.dispose();
  }
}
