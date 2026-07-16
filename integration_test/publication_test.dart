import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/widgets/widgets.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

/// TC2 (Topic Search) and TC3 (Publication Detail) on the Home tab.
void main() {
  patrolTest('TC2: searching a topic shows the overview', ($) async {
    await pumpShell($);
    await searchTopic($, 'machine learning');

    // The overview dashboard renders its headline metrics.
    await $.waitUntilVisible(
      $('Total publications'),
      timeout: const Duration(seconds: 30),
    );
    expect($('Publications over time'), findsWidgets);
    expect($('Most active year'), findsWidgets);
  });

  patrolTest('TC3: opening a publication shows its detail', ($) async {
    await pumpShell($);
    await searchTopic($, 'machine learning');
    await $.waitUntilVisible(
      $('Most influential publication'),
      timeout: const Duration(seconds: 30),
    );

    // Tap the most-influential paper card to push its detail screen.
    await $(PaperCard).tap();

    await $.waitUntilVisible($('Publication')); // detail app-bar title
    expect($('Authors'), findsWidgets);
    expect($('Abstract'), findsWidgets);
  });
}
