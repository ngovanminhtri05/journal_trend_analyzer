import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:journal_trend_analyzer/firebase/app_user.dart';
import 'package:journal_trend_analyzer/firebase/auth_service.dart';
import 'package:journal_trend_analyzer/firebase/remote_config_service.dart';
import 'package:journal_trend_analyzer/firebase_options.dart';
import 'package:journal_trend_analyzer/main.dart';
import 'package:journal_trend_analyzer/screens/home_shell.dart';
import 'package:journal_trend_analyzer/viewmodels/auth_viewmodel.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart' show ChangeNotifierProvider;

/// Shared Patrol helpers for the Lab 03 E2E suite.
///
/// Feature tests (search / journals / keywords) pump the app with
/// `home: HomeShell()` to bypass the Google Sign-In gate — so they are
/// deterministic and independent of the device's auth state. The auth test and
/// the export test drive the real Login → Google → Home flow (which needs a
/// Google account on the device); the profile/remote-config tests inject a fake
/// signed-in session so they need neither the native chooser nor network.
///
/// The search-based tests exercise the live OpenAlex API, so they need network
/// access and a device/emulator with Google Play Services.

Future<void> _initFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

/// Boots the app straight into the 4-tab shell (auth bypassed).
Future<void> pumpShell(PatrolIntegrationTester $) async {
  await _initFirebase();
  await $.pumpWidgetAndSettle(const JournalTrendApp(home: HomeShell()));
}

/// Boots the shell with a fake signed-in session above it, so the Profile tab
/// shows the account + Firebase demo cards without the native Google flow.
///
/// [remoteConfig] lets a test inject deterministic, non-default tunables (see
/// [StaticRemoteConfig]) instead of the uninitialised [RemoteConfigService]'s
/// in-code defaults, so the Remote Config wiring itself gets exercised.
Future<void> pumpSignedInShell(
  PatrolIntegrationTester $, {
  RemoteConfigApi? remoteConfig,
}) async {
  await _initFirebase();
  await $.pumpWidgetAndSettle(
    JournalTrendApp(
      remoteConfig: remoteConfig,
      home: ChangeNotifierProvider<AuthViewModel>(
        create: (_) => AuthViewModel(_FakeSignedInAuth()),
        child: const HomeShell(),
      ),
    ),
  );
}

/// Boots the real app (through the auth gate) for the sign-in / sign-out flow.
Future<void> pumpRealApp(PatrolIntegrationTester $) async {
  await _initFirebase();
  await $.pumpWidget(const JournalTrendApp());
  await $.pump(const Duration(seconds: 2));
}

/// Drives the real Login → native Google chooser → Home flow. Requires a Google
/// account already added to the device.
Future<void> signInWithGoogle(PatrolIntegrationTester $) async {
  await $('Continue with Google').tap();
  // ignore: deprecated_member_use
  await $.native.tap(Selector(textContains: '@'));
  await $.waitUntilVisible(
    $(NavigationBar),
    timeout: const Duration(seconds: 30),
  );
}

/// Switches to a bottom-navigation tab by its label.
Future<void> openTab(PatrolIntegrationTester $, String label) async {
  await $(label).tap();
  await $.pumpAndSettle();
}

/// Types [query] into the visible tab's topic search bar and submits it.
/// Off-stage tabs are excluded from the finder, so `$(TextField)` is unambiguous.
Future<void> searchTopic(PatrolIntegrationTester $, String query) async {
  await $(TextField).enterText(query);
  await $(Icons.arrow_forward).tap();
  await $.pump(const Duration(seconds: 1));
  await $.waitUntilVisible($(Scaffold), timeout: const Duration(seconds: 30));
}

/// A stand-in [AuthApi] that reports one already-signed-in user, for tests that
/// need the signed-in Profile UI without touching Firebase Auth.
class _FakeSignedInAuth implements AuthApi {
  static const _user = AppUser(
    uid: 'e2e-user',
    displayName: 'E2E Tester',
    email: 'e2e@example.com',
  );

  @override
  Stream<AppUser?> get authStateChanges => Stream<AppUser?>.value(_user);

  @override
  AppUser? get currentUser => _user;

  @override
  Future<AppUser?> signInWithGoogle() async => _user;

  @override
  Future<void> signOut() async {}
}
