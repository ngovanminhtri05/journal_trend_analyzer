import 'package:flutter/foundation.dart';

import '../firebase/admin_users_service.dart';
import 'view_state.dart';

/// Drives the admin Users screen: list, disable/enable, delete.
class AdminUsersViewModel extends ChangeNotifier {
  AdminUsersViewModel(this._api);

  final AdminUsersApi _api;

  ViewState state = ViewState.idle;
  String? errorMessage;
  List<AdminUserSummary> users = const [];

  final Set<String> _busyUids = {};

  /// Whether a disable/delete action for [uid] is currently in flight.
  bool isBusy(String uid) => _busyUids.contains(uid);

  Future<void> load() async {
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final page = await _api.listUsers();
      users = page.users;
      state = users.isEmpty ? ViewState.empty : ViewState.success;
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

  Future<void> setDisabled(String uid, bool disabled) async {
    _busyUids.add(uid);
    notifyListeners();
    try {
      await _api.setUserDisabled(uid: uid, disabled: disabled);
      users = [
        for (final u in users)
          if (u.uid == uid)
            AdminUserSummary(
              uid: u.uid,
              email: u.email,
              displayName: u.displayName,
              disabled: disabled,
              createdAt: u.createdAt,
              isAdmin: u.isAdmin,
            )
          else
            u,
      ];
    } on AdminException catch (e) {
      errorMessage = e.message;
    } finally {
      _busyUids.remove(uid);
      notifyListeners();
    }
  }

  Future<void> delete(String uid) async {
    _busyUids.add(uid);
    notifyListeners();
    try {
      await _api.deleteUser(uid);
      users = users.where((u) => u.uid != uid).toList();
    } on AdminException catch (e) {
      errorMessage = e.message;
    } finally {
      _busyUids.remove(uid);
      notifyListeners();
    }
  }
}
