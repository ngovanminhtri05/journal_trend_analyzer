import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/widgets/widgets.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

/// TC4 (Journals navigation) and TC5 (Journal Detail).
void main() {
  patrolTest('TC4: Journals tab ranks top journals for a topic', ($) async {
    await pumpShell($);
    await openTab($, 'Journals');
    await searchTopic($, 'robotics');

    await $.waitUntilVisible(
      $('Top journals'),
      timeout: const Duration(seconds: 30),
    );
    expect($('Publications across top journals'), findsWidgets);
  });

  patrolTest('TC5: opening a journal shows its detail', ($) async {
    await pumpShell($);
    await openTab($, 'Journals');
    await searchTopic($, 'robotics');
    await $.waitUntilVisible(
      $('Top journals'),
      timeout: const Duration(seconds: 30),
    );

    // Tap the first ranked journal row to push its detail screen.
    await $(RankedCountList).$(InkWell).first.tap();

    await $.waitUntilVisible(
      $('Total publications'),
      timeout: const Duration(seconds: 30),
    );
    expect($('Most cited publications'), findsWidgets);
  });
}
