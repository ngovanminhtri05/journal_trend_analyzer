import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Writes PDF report [bytes] as [fileName] and returns the saved file path.
/// Injected into [HomeViewModel] so tests can substitute a no-plugin fake.
typedef ReportFileSaver =
    Future<String> Function(Uint8List bytes, String fileName);

/// Default saver: writes the report into the app's temporary directory. The OS
/// share sheet then reads it from there — no backend or billing required.
Future<String> saveReportToTemp(Uint8List bytes, String fileName) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}
