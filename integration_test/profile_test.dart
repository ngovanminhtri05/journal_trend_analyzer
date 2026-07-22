import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

/// TC8 (Profile navigation) and TC10 (Remote Config applied).
///
/// Use a fake signed-in session so the Profile UI renders deterministically
/// without the native Google chooser or network.
void main() {
  patrolTest('TC8: Profile tab shows the signed-in account', ($) async {
    await pumpSignedInShell($);
    await openTab($, 'Profile');

    expect($('E2E Tester'), findsWidgets);
    expect($('e2e@example.com'), findsWidgets);
    expect($('Sign out'), findsOneWidget);
  });

  patrolTest('TC10: Profile shows the Remote Config values', ($) async {
    await pumpSignedInShell($);
    await openTab($, 'Profile');

    // The Remote Config card reports the two server-tunable list limits
    // (in-code defaults 15 / 20 when the server has no override).
    expect($('Remote Config'), findsWidgets);
    expect($('Max journals'), findsWidgets);
    expect($('Max keywords'), findsWidgets);
    expect($('15'), findsWidgets);
    expect($('20'), findsWidgets);
  });

  patrolTest('TC8b: Profile hides the Admin Dashboard for a non-admin session', (
    $,
  ) async {
    await pumpSignedInShell($);
    await openTab($, 'Profile');

    expect($('Admin Dashboard'), findsNothing);
  });
}
