import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/remote_config_service.dart';
import 'package:journal_trend_analyzer/screens/keywords_screen.dart';
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

  patrolTest(
    'TC10: Remote Config values reach the Profile card and cap the ranked lists',
    ($) async {
      // Deliberately different from the in-code defaults (15 / 20): a passing
      // assertion below proves the UI is actually driven by RemoteConfigApi,
      // not just displaying the hardcoded fallback values.
      const remoteConfig = StaticRemoteConfig(maxJournals: 4, maxKeywords: 6);
      await pumpSignedInShell($, remoteConfig: remoteConfig);

      await openTab($, 'Profile');
      expect($('Remote Config'), findsWidgets);
      expect($('Max journals'), findsWidgets);
      expect($('Max keywords'), findsWidgets);
      expect($('4'), findsWidgets);
      expect($('6'), findsWidgets);

      // The same config also bounds the Journals/Keywords tab list lengths.
      // "robotics" reliably has far more than 4 distinct journals, so a count
      // <= 4 here only holds if the injected limit is actually enforced.
      await openTab($, 'Journals');
      await searchTopic($, 'robotics');
      await $.waitUntilVisible(
        $('Top journals'),
        timeout: const Duration(seconds: 30),
      );
      final journalRows = find.byType(LinearProgressIndicator).evaluate().length;
      expect(journalRows, greaterThan(0));
      expect(journalRows, lessThanOrEqualTo(4));

      await openTab($, 'Keywords');
      await searchTopic($, 'genomics');
      await $.waitUntilVisible(
        $('Most frequent keywords'),
        timeout: const Duration(seconds: 30),
      );
      final keywordRows = find.byType(KeywordRankRow).evaluate().length;
      expect(keywordRows, greaterThan(0));
      expect(keywordRows, lessThanOrEqualTo(6));
    },
  );
}
