import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Contract for uploading generated report files (Lab 03 task 8.3).
///
/// ViewModels depend on this, never on `firebase_storage` directly, so the
/// export flow stays testable.
abstract interface class ReportStorageApi {
  /// Uploads [bytes] as a PDF under the signed-in user's folder and returns a
  /// public download URL.
  Future<String> uploadReport({
    required String uid,
    required Uint8List bytes,
    required String fileName,
  });
}

/// Firebase-backed [ReportStorageApi]. [FirebaseStorage.instance] is resolved
/// lazily so constructing this never requires Firebase.
class StorageService implements ReportStorageApi {
  StorageService({FirebaseStorage? storage}) : _injected = storage;

  final FirebaseStorage? _injected;
  FirebaseStorage get _storage => _injected ?? FirebaseStorage.instance;

  @override
  Future<String> uploadReport({
    required String uid,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ref = _storage.ref('reports/$uid/$fileName');
    await ref.putData(bytes, SettableMetadata(contentType: 'application/pdf'));
    return ref.getDownloadURL();
  }
}
