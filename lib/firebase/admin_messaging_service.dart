import 'package:cloud_functions/cloud_functions.dart';

import 'admin_users_service.dart' show AdminException;

/// Contract for the admin push Cloud Functions.
abstract interface class AdminMessagingApi {
  /// Sends a notification to every subscribed install (the `broadcast` topic).
  Future<void> sendBroadcast({required String title, required String body});

  /// Sends a notification to one user's per-user topic (`user_<uid>`).
  Future<void> sendToUser({
    required String uid,
    required String title,
    required String body,
  });
}

/// Calls the `adminSendNotification` Cloud Function
/// (`functions/src/notifications.ts`). [FirebaseFunctions.instance] is resolved
/// lazily so constructing this never requires Firebase.
class AdminMessagingService implements AdminMessagingApi {
  AdminMessagingService({FirebaseFunctions? functions}) : _injected = functions;

  final FirebaseFunctions? _injected;
  FirebaseFunctions get _functions => _injected ?? FirebaseFunctions.instance;

  @override
  Future<void> sendBroadcast({
    required String title,
    required String body,
  }) async {
    try {
      await _functions.httpsCallable('adminSendNotification').call<dynamic>({
        'title': title,
        'body': body,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to send the notification.');
    }
  }

  @override
  Future<void> sendToUser({
    required String uid,
    required String title,
    required String body,
  }) async {
    try {
      await _functions.httpsCallable('adminSendNotificationToUser').call<dynamic>(
        {'uid': uid, 'title': title, 'body': body},
      );
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to send the notification.');
    }
  }
}
