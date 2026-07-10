import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/messaging_service.dart';

/// Notification Center (Lab 03 task 8.2).
///
/// Subscribes to foreground FCM messages via [MessagingApi] and keeps a local,
/// persisted list of what was received. Holds the device FCM token so it can be
/// shown (and copied) to target a test push. No Firebase types leak in — it is
/// unit-testable with a fake [MessagingApi].
class NotificationsViewModel extends ChangeNotifier {
  NotificationsViewModel(this._messaging, {SharedPreferences? prefs})
    : _prefs = prefs;

  static const String _storageKey = 'notifications_v1';
  static const int _maxStored = 50;

  final MessagingApi _messaging;
  SharedPreferences? _prefs;
  StreamSubscription<AppNotification>? _sub;

  final List<AppNotification> _items = [];
  List<AppNotification> get notifications => List.unmodifiable(_items);

  /// The device FCM token, once resolved (for display / targeting a test push).
  String? token;

  Future<SharedPreferences> get _preferences async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Loads persisted notifications, subscribes to incoming messages, and
  /// requests permission + the FCM token.
  Future<void> load() async {
    final prefs = await _preferences;
    final raw = prefs.getStringList(_storageKey) ?? const [];
    _items
      ..clear()
      ..addAll(
        raw.map(
          (s) =>
              AppNotification.fromJson(jsonDecode(s) as Map<String, dynamic>),
        ),
      );
    notifyListeners();

    // Subscribe only after the persisted list is in place, so an incoming
    // message can't be clobbered by the initial load.
    _sub ??= _messaging.onMessage.listen(add);

    try {
      token = await _messaging.initialize();
      notifyListeners();
    } catch (_) {
      // Permission denied / no Play Services — leave token null.
    }
  }

  /// Adds a received notification to the front of the list and persists it.
  void add(AppNotification notification) {
    _items.insert(0, notification);
    if (_items.length > _maxStored) {
      _items.removeRange(_maxStored, _items.length);
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
      _storageKey,
      _items.map((n) => jsonEncode(n.toJson())).toList(),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
