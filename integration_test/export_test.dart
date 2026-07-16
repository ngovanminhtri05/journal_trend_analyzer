import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

/// TC9 (PDF report export).
///
/// Exporting builds the PDF, saves it locally, and opens the OS share sheet;
/// when Firebase Storage is enabled it also uploads and shows the download URL.
/// The local path needs no billing, so this runs on the auth-bypassed shell and
/// just verifies the export completes without an error.
void main() {
  patrolTest('TC9: exporting a report completes and opens the share sheet', (
    $,
  ) async {
    await pumpShell($);

    // Load an overview on the Home tab.
    await searchTopic($, 'machine learning');
    await $.waitUntilVisible(
      $('Export PDF report'),
      timeout: const Duration(seconds: 30),
    );

    await $('Export PDF report').tap();
    await $.pump(const Duration(seconds: 2));

    // No failure surfaced (the native share sheet is presented on success).
    expect($('Failed to export the report. Please try again.'), findsNothing);

    // Dismiss the native share sheet if it is showing.
    // ignore: deprecated_member_use
    await $.native.pressBack();
  });
}
