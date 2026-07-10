import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

/// TC9 (PDF report export + upload to Firebase Storage).
///
/// Uses the real Google sign-in so the upload carries a genuine Firebase Auth
/// session — the Storage rules (`reports/{uid}`, owner-only) require it. Needs
/// Storage enabled in the Firebase console.
void main() {
  patrolTest('TC9: exporting a report uploads it and shows the URL', ($) async {
    await pumpRealApp($);
    await signInWithGoogle($);

    // Load an overview on the Home tab.
    await searchTopic($, 'machine learning');
    await $.waitUntilVisible(
      $('Export PDF report'),
      timeout: const Duration(seconds: 30),
    );

    // Build + upload the PDF; the success dialog shows the download URL.
    await $('Export PDF report').tap();
    await $.waitUntilVisible(
      $('Report uploaded'),
      timeout: const Duration(seconds: 30),
    );
    expect($('Copy link'), findsOneWidget);

    await $('Done').tap();
  });
}
