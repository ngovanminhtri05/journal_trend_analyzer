import 'package:cloud_functions/cloud_functions.dart';

import 'admin_users_service.dart' show AdminException;

/// One Remote Config parameter, as shown/edited on the admin screen.
class RemoteConfigParam {
  const RemoteConfigParam({required this.key, required this.defaultValue});

  final String key;
  final String defaultValue;

  factory RemoteConfigParam.fromMap(Map<String, dynamic> map) =>
      RemoteConfigParam(
        key: map['key'] as String,
        defaultValue: (map['defaultValue'] as String?) ?? '',
      );
}

/// Contract for the admin Remote Config Cloud Functions.
abstract interface class AdminRemoteConfigApi {
  Future<List<RemoteConfigParam>> getTemplate();
  Future<void> updateParameter({
    required String key,
    required String defaultValue,
  });
}

/// Calls the `adminGetRemoteConfigTemplate` / `adminUpdateRemoteConfigParameter`
/// Cloud Functions (`functions/src/remote-config.ts`).
class AdminRemoteConfigService implements AdminRemoteConfigApi {
  AdminRemoteConfigService({FirebaseFunctions? functions})
    : _injected = functions;

  final FirebaseFunctions? _injected;
  FirebaseFunctions get _functions => _injected ?? FirebaseFunctions.instance;

  @override
  Future<List<RemoteConfigParam>> getTemplate() async {
    try {
      final result = await _functions
          .httpsCallable('adminGetRemoteConfigTemplate')
          .call<dynamic>();
      final data = Map<String, dynamic>.from(result.data as Map);
      return (data['parameters'] as List)
          .map(
            (p) => RemoteConfigParam.fromMap(Map<String, dynamic>.from(p as Map)),
          )
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to load Remote Config.');
    }
  }

  @override
  Future<void> updateParameter({
    required String key,
    required String defaultValue,
  }) async {
    try {
      await _functions
          .httpsCallable('adminUpdateRemoteConfigParameter')
          .call<dynamic>({'key': key, 'defaultValue': defaultValue});
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to update the parameter.');
    }
  }
}
