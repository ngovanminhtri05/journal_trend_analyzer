import 'package:flutter/foundation.dart';

import '../firebase/admin_messaging_service.dart';
import '../firebase/admin_users_service.dart' show AdminException;

/// Drives the admin Send-Notification screen. With no [targetUid] it broadcasts
/// to every user; with a [targetUid] it notifies just that user (used from the
/// admin user-detail screen).
class AdminSendNotificationViewModel extends ChangeNotifier {
  AdminSendNotificationViewModel(this._api, {this.targetUid});

  final AdminMessagingApi _api;

  /// When set, [send] targets this single user instead of broadcasting.
  final String? targetUid;

  bool sending = false;
  String? errorMessage;

  /// True right after a successful send (so the screen can confirm + reset).
  bool sent = false;

  Future<void> send({required String title, required String body}) async {
    final t = title.trim();
    final b = body.trim();
    if (t.isEmpty || b.isEmpty) {
      errorMessage = 'Enter both a title and a message.';
      sent = false;
      notifyListeners();
      return;
    }

    sending = true;
    errorMessage = null;
    sent = false;
    notifyListeners();

    try {
      final uid = targetUid;
      if (uid != null) {
        await _api.sendToUser(uid: uid, title: t, body: b);
      } else {
        await _api.sendBroadcast(title: t, body: b);
      }
      sent = true;
    } on AdminException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
    }

    sending = false;
    notifyListeners();
  }
}
