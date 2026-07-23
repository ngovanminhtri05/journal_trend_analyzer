import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/messaging_service.dart';
import 'package:journal_trend_analyzer/viewmodels/notifications_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory [MessagingApi] with a controllable foreground stream.
class _FakeMessaging implements MessagingApi {
  final _controller = StreamController<AppNotification>.broadcast();
  final _openedController = StreamController<AppNotification>.broadcast();
  String? tokenToReturn = 'fake-token';
  Object? initError;

  void emit(AppNotification n) => _controller.add(n);
  void emitOpened(AppNotification n) => _openedController.add(n);

  @override
  Stream<AppNotification> get onMessage => _controller.stream;

  @override
  Stream<AppNotification> get onMessageOpenedApp => _openedController.stream;

  @override
  Future<String?> initialize() async {
    if (initError != null) throw initError!;
    return tokenToReturn;
  }

  @override
  Future<AppNotification?> initialMessage() async => null;

  final subscribedUsers = <String>[];
  final unsubscribedUsers = <String>[];

  @override
  Future<void> subscribeToUser(String uid) async => subscribedUsers.add(uid);

  @override
  Future<void> unsubscribeFromUser(String uid) async =>
      unsubscribedUsers.add(uid);

  void dispose() {
    _controller.close();
    _openedController.close();
  }
}

// Distinct timestamps so the head-dedupe in the ViewModel does not merge them.
AppNotification _n(String title) => AppNotification(
  title: title,
  body: 'body',
  receivedAt: DateTime(2026, 7, 9, 0, title.hashCode.abs() % 60),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'collects a foreground message and exposes the token after load',
    () async {
      final messaging = _FakeMessaging();
      final vm = NotificationsViewModel(messaging);
      addTearDown(() {
        vm.dispose();
        messaging.dispose();
      });

      await vm.load();
      expect(vm.token, 'fake-token');

      messaging.emit(_n('Hello'));
      await Future<void>.delayed(Duration.zero);

      expect(vm.notifications, hasLength(1));
      expect(vm.notifications.first.title, 'Hello');
    },
  );

  test('newest notification is first and clear empties the list', () async {
    final messaging = _FakeMessaging();
    final vm = NotificationsViewModel(messaging);
    addTearDown(() {
      vm.dispose();
      messaging.dispose();
    });
    await vm.load();

    messaging.emit(_n('First'));
    await Future<void>.delayed(Duration.zero);
    messaging.emit(_n('Second'));
    await Future<void>.delayed(Duration.zero);

    expect(vm.notifications.first.title, 'Second');
    expect(vm.notifications, hasLength(2));

    await vm.clear();
    expect(vm.notifications, isEmpty);
  });

  test('persists notifications across instances', () async {
    final messaging = _FakeMessaging();
    final vm = NotificationsViewModel(messaging);
    await vm.load();
    messaging.emit(_n('Persisted'));
    await Future<void>.delayed(Duration.zero);
    vm.dispose();

    // A fresh ViewModel (same prefs) should reload the stored notification.
    final messaging2 = _FakeMessaging();
    final vm2 = NotificationsViewModel(messaging2);
    addTearDown(() {
      vm2.dispose();
      messaging.dispose();
      messaging2.dispose();
    });
    await vm2.load();

    expect(vm2.notifications, hasLength(1));
    expect(vm2.notifications.first.title, 'Persisted');
  });

  test('leaves token null when initialize fails', () async {
    final messaging = _FakeMessaging()..initError = Exception('denied');
    final vm = NotificationsViewModel(messaging);
    addTearDown(() {
      vm.dispose();
      messaging.dispose();
    });

    await vm.load();
    expect(vm.token, isNull);
  });
}
