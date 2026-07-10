import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase_options.dart';
import 'package:journal_trend_analyzer/main.dart';
import 'package:journal_trend_analyzer/screens/home_shell.dart';
import 'package:patrol/patrol.dart';

/// Patrol E2E smoke test (Lab 03 task 10.1).
///
/// Boots the app (with Firebase initialised on-device) into the navigation shell
/// — bypassing the Google Sign-In gate so the smoke test is independent of the
/// device's auth state — and asserts the four tabs render.
void main() {
  patrolTest('app boots into the 4-tab shell', ($) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await $.pumpWidgetAndSettle(
      const JournalTrendApp(home: HomeShell()),
    );

    expect($('Home'), findsWidgets);
    expect($('Journals'), findsWidgets);
    expect($('Keywords'), findsWidgets);
    expect($('Profile'), findsWidgets);
  });
}
