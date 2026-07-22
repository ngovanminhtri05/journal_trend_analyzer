import 'package:flutter/foundation.dart';

import '../firebase/admin_remote_config_service.dart';
import '../firebase/admin_users_service.dart' show AdminException;
import 'view_state.dart';

/// Drives the admin Remote Config screen: view + edit parameters.
class AdminRemoteConfigViewModel extends ChangeNotifier {
  AdminRemoteConfigViewModel(this._api);

  final AdminRemoteConfigApi _api;

  ViewState state = ViewState.idle;
  String? errorMessage;
  List<RemoteConfigParam> parameters = const [];

  Future<void> load() async {
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      parameters = await _api.getTemplate();
      state = parameters.isEmpty ? ViewState.empty : ViewState.success;
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

  Future<void> updateParameter(String key, String defaultValue) async {
    errorMessage = null;
    try {
      await _api.updateParameter(key: key, defaultValue: defaultValue);
      parameters = [
        for (final p in parameters)
          if (p.key == key)
            RemoteConfigParam(key: key, defaultValue: defaultValue)
          else
            p,
        if (!parameters.any((p) => p.key == key))
          RemoteConfigParam(key: key, defaultValue: defaultValue),
      ];
    } on AdminException catch (e) {
      errorMessage = e.message;
    }
    notifyListeners();
  }
}
