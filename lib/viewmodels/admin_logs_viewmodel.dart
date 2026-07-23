import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase/admin_logs_service.dart';
import 'view_state.dart';

/// Drives the admin Logs screen: the mirrored Analytics/Crashlytics feed.
class AdminLogsViewModel extends ChangeNotifier {
  AdminLogsViewModel(this._api);

  final AdminLogsApi _api;

  ViewState state = ViewState.idle;
  String? errorMessage;
  List<AdminEventLog> events = const [];

  Future<void> load() async {
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      events = await _api.recentEvents();
      state = events.isEmpty ? ViewState.empty : ViewState.success;
    } on FirebaseException catch (e) {
      // The project has no Firestore database yet — retrying can't help; tell
      // the admin exactly what to do instead of a generic "try again".
      errorMessage = e.code == 'not-found'
          ? 'Logs need a Firestore database. In the Firebase console, create '
                'the (default) database, then reopen this screen.'
          : 'Could not load logs. Please try again.';
      state = ViewState.error;
    } catch (_) {
      errorMessage = 'Could not load logs. Please try again.';
      state = ViewState.error;
    }
    notifyListeners();
  }

  Future<void> retry() => load();
}
