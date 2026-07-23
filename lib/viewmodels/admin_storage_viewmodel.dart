import 'package:flutter/foundation.dart';

import '../firebase/admin_storage_service.dart';
import '../firebase/admin_users_service.dart' show AdminException;
import 'view_state.dart';

/// Drives the admin Storage screen: browse/download/delete uploaded reports
/// across all users.
class AdminStorageViewModel extends ChangeNotifier {
  AdminStorageViewModel(this._api, {this.uid});

  final AdminStorageApi _api;

  /// When set, only this user's reports are listed (admin user-detail screen).
  final String? uid;

  ViewState state = ViewState.idle;
  String? errorMessage;
  List<AdminReportFile> reports = const [];

  Future<void> load() async {
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      reports = await _api.listReports(uid: uid);
      state = reports.isEmpty ? ViewState.empty : ViewState.success;
    } on AdminException catch (e) {
      errorMessage = e.message;
      state = ViewState.error;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      state = ViewState.error;
    }
    notifyListeners();
  }

  Future<void> retry() => load();

  Future<String> openReport(String path) => _api.getReportUrl(path);

  Future<void> delete(String path) async {
    try {
      await _api.deleteReport(path);
      reports = reports.where((r) => r.path != path).toList();
      // Deleting the last report should show the empty state, not a blank list.
      if (reports.isEmpty) state = ViewState.empty;
    } on AdminException catch (e) {
      errorMessage = e.message;
    }
    notifyListeners();
  }
}
