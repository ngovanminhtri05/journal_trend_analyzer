import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

/// TC1 (Google Sign-In) and TC11 (Logout).
///
/// These drive the real auth gate and the native Google account chooser, so they
/// need a device with a Google account already added. `clearPackageData` (set in
/// the Gradle test config) wipes app state between tests, so each starts signed
/// out at the Login screen.
void main() {
  patrolTest('TC1: Google Sign-In lands on the Home shell', ($) async {
    await pumpRealApp($);

    // Signed out → Login screen.
    expect($('Continue with Google'), findsOneWidget);

    await signInWithGoogle($);

    // Back in the app, the 4-tab shell is shown.
    expect($('Home'), findsWidgets);
    expect($('Profile'), findsWidgets);
  });

  patrolTest('TC11: Sign out returns to the Login screen', ($) async {
    await pumpRealApp($);

    // Sign in first (clearPackageData means we start signed out).
    await signInWithGoogle($);

    // Go to Profile and sign out. "Sign out" is the last item in the Profile
    // ListView — on real devices the card stack overflows the viewport, so
    // it needs a scroll to become hit-testable.
    await openTab($, 'Profile');
    await $.scrollUntilVisible(finder: $('Sign out').finder);
    await $('Sign out').tap();

    // Back to the Login screen.
    await $.waitUntilVisible(
      $('Continue with Google'),
      timeout: const Duration(seconds: 15),
    );
    expect($('Continue with Google'), findsOneWidget);
  });
}
