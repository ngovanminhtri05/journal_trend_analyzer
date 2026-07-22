import 'package:cloud_firestore/cloud_firestore.dart';

/// A mirrored analytics event, read back for the admin Logs screen.
class AdminEventLog {
  const AdminEventLog({
    required this.uid,
    required this.name,
    required this.timestamp,
    this.params = const {},
  });

  final String uid;
  final String name;
  final DateTime timestamp;
  final Map<String, dynamic> params;

  factory AdminEventLog.fromMap(Map<String, dynamic> map) => AdminEventLog(
    uid: map['uid'] as String? ?? '',
    name: map['name'] as String? ?? '',
    timestamp:
        (map['timestamp'] as Timestamp?)?.toDate() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    params: Map<String, dynamic>.from(map['params'] as Map? ?? const {}),
  );
}

/// A mirrored crash/error record, read back for the admin Logs screen.
class AdminCrashLog {
  const AdminCrashLog({
    required this.uid,
    required this.message,
    required this.timestamp,
    this.reason,
  });

  final String uid;
  final String message;
  final DateTime timestamp;
  final String? reason;

  factory AdminCrashLog.fromMap(Map<String, dynamic> map) => AdminCrashLog(
    uid: map['uid'] as String? ?? '',
    message: map['message'] as String? ?? '',
    timestamp:
        (map['timestamp'] as Timestamp?)?.toDate() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    reason: map['reason'] as String?,
  );
}

/// Contract for reading the mirrored admin logs (Firestore-backed). Only an
/// admin's Firestore rules allow these reads — see `firestore.rules`.
abstract interface class AdminLogsApi {
  Future<List<AdminEventLog>> recentEvents({int limit = 100});
  Future<List<AdminCrashLog>> recentCrashes({int limit = 100});
}

/// Firebase-backed [AdminLogsApi]. [FirebaseFirestore.instance] is resolved
/// lazily so constructing this never requires Firebase.
class AdminLogsService implements AdminLogsApi {
  AdminLogsService({FirebaseFirestore? firestore}) : _injected = firestore;

  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  @override
  Future<List<AdminEventLog>> recentEvents({int limit = 100}) async {
    final snapshot = await _db
        .collection('admin_events')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((d) => AdminEventLog.fromMap(d.data())).toList();
  }

  @override
  Future<List<AdminCrashLog>> recentCrashes({int limit = 100}) async {
    final snapshot = await _db
        .collection('admin_crash_reports')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((d) => AdminCrashLog.fromMap(d.data())).toList();
  }
}
