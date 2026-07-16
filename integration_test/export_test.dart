import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

/// TC9 (PDF report export + Firebase Storage upload).
///
/// Exporting builds the PDF, saves it locally, opens the OS share sheet, and —
/// once the Firebase Storage upload finishes — shows a "Report uploaded"
/// dialog with the download URL. That dialog only appears when the upload
/// (`HomeViewModel.reportUrl`) actually succeeded, so asserting on it is the
/// client-observable proof of a successful Storage upload. It requires a real
/// signed-in Firebase user (Storage rules scope writes to the caller's uid),
/// so this drives the real Login -> Google -> Home flow, same as TC1/TC11.
void main() {
  patrolTest(
    'TC9: exporting a report uploads the PDF to Firebase Storage',
    ($) async {
      await pumpRealApp($);
      await signInWithGoogle($);

      // Load an overview on the Home tab.
      await searchTopic($, 'machine learning');
      await $.waitUntilVisible(
        $('Export PDF report'),
        timeout: const Duration(seconds: 30),
      );

      await $('Export PDF report').tap();
      await $.pump(const Duration(seconds: 2));

      // No failure surfaced (the native share sheet is presented on success).
      expect(
        $('Failed to export the report. Please try again.'),
        findsNothing,
      );

      // Dismiss the native share sheet so the app regains focus and the
      // post-share upload dialog (awaited after the share call) can appear.
      // ignore: deprecated_member_use
      await $.native.pressBack();

      await $.waitUntilVisible(
        $('Report uploaded'),
        timeout: const Duration(seconds: 30),
      );
      expect(
        $('Your PDF report is also stored in Firebase Storage:'),
        findsOneWidget,
      );

      final url = $.tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data;
      expect(url, isNotNull);
      expect(url, contains('firebasestorage'));

      await $('Done').tap();
    },
  );
}
