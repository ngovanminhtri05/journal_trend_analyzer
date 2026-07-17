import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/screens/keywords_screen.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

/// TC6 (Keywords navigation) and TC7 (Keyword Detail).
void main() {
  patrolTest('TC6: Keywords tab ranks frequent keywords for a topic', ($) async {
    await pumpShell($);
    await openTab($, 'Keywords');
    await searchTopic($, 'genomics');

    await $.waitUntilVisible(
      $('Most frequent keywords'),
      timeout: const Duration(seconds: 30),
    );
    expect($(KeywordRankRow), findsWidgets);
  });

  patrolTest('TC7: opening a keyword shows its analysis', ($) async {
    await pumpShell($);
    await openTab($, 'Keywords');
    await searchTopic($, 'genomics');
    await $.waitUntilVisible(
      $(KeywordRankRow),
      timeout: const Duration(seconds: 30),
    );

    // Tap the first keyword row to push its analysis screen.
    await $(KeywordRankRow).first.tap();

    await $.waitUntilVisible(
      $('Publications over time'),
      timeout: const Duration(seconds: 30),
    );
    expect($('Top contributing authors'), findsWidgets);
  });
}
