import 'package:cloud_functions/cloud_functions.dart';

import 'admin_users_service.dart' show AdminException;

/// One uploaded report, as shown on the admin Storage screen.
class AdminReportFile {
  const AdminReportFile({
    required this.path,
    required this.size,
    this.uploadedAt,
    this.uid,
  });

  final String path;
  final int size;
  final String? uploadedAt;
  final String? uid;

  factory AdminReportFile.fromMap(Map<String, dynamic> map) => AdminReportFile(
    path: map['path'] as String,
    size: (map['size'] as num?)?.toInt() ?? 0,
    uploadedAt: map['uploadedAt'] as String?,
    uid: map['uid'] as String?,
  );
}

/// Contract for the admin Storage (reports) Cloud Functions.
abstract interface class AdminStorageApi {
  /// Lists uploaded reports; scoped to one user's folder when [uid] is given.
  Future<List<AdminReportFile>> listReports({String? uid});
  Future<String> getReportUrl(String path);
  Future<void> deleteReport(String path);
}

/// Calls the `adminListReports` / `adminGetReportUrl` / `adminDeleteReport`
/// Cloud Functions (`functions/src/storage.ts`).
class AdminStorageService implements AdminStorageApi {
  AdminStorageService({FirebaseFunctions? functions}) : _injected = functions;

  final FirebaseFunctions? _injected;
  FirebaseFunctions get _functions => _injected ?? FirebaseFunctions.instance;

  @override
  Future<List<AdminReportFile>> listReports({String? uid}) async {
    try {
      final result = await _functions
          .httpsCallable('adminListReports')
          .call<dynamic>({'uid': ?uid});
      final data = Map<String, dynamic>.from(result.data as Map);
      return (data['reports'] as List)
          .map(
            (r) => AdminReportFile.fromMap(Map<String, dynamic>.from(r as Map)),
          )
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to list reports.');
    }
  }

  @override
  Future<String> getReportUrl(String path) async {
    try {
      final result = await _functions
          .httpsCallable('adminGetReportUrl')
          .call<dynamic>({'path': path});
      final data = Map<String, dynamic>.from(result.data as Map);
      return data['url'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to get a download link.');
    }
  }

  @override
  Future<void> deleteReport(String path) async {
    try {
      await _functions.httpsCallable('adminDeleteReport').call<dynamic>({
        'path': path,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AdminException(e.message ?? 'Failed to delete the report.');
    }
  }
}
