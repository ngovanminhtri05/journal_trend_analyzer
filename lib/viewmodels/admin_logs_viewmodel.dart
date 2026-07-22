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
  List<AdminCrashLog> crashes = const [];

  Future<void> load() async {
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.recentEvents(),
        _api.recentCrashes(),
      ]);
      events = results[0] as List<AdminEventLog>;
      crashes = results[1] as List<AdminCrashLog>;
      state = (events.isEmpty && crashes.isEmpty)
          ? ViewState.empty
          : ViewState.success;
    } catch (_) {
      errorMessage = 'Could not load logs. Please try again.';
      state = ViewState.error;
    }
    notifyListeners();
  }

  Future<void> retry() => load();
}
