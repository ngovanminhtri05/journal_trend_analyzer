import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/widgets/widgets.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

/// TC4 (Journals navigation) and TC5 (Journal Detail).
///
/// The wait anchors on the success-only summary `StatCard` (its label renders
/// upper-cased, "PUBLICATIONS ACROSS TOP JOURNALS") rather than the "Top
/// journals" heading, because the search-bar hint also contains that heading
/// text and would satisfy the wait before results have loaded.
void main() {
  patrolTest('TC4: Journals tab ranks top journals for a topic', ($) async {
    await pumpShell($);
    await openTab($, 'Journals');
    await searchTopic($, 'robotics');

    await $.waitUntilVisible(
      $('PUBLICATIONS ACROSS TOP JOURNALS'),
      timeout: const Duration(seconds: 45),
    );
    expect($('Top journals'), findsWidgets);
  });

  patrolTest('TC5: opening a journal shows its detail', ($) async {
    await pumpShell($);
    await openTab($, 'Journals');
    await searchTopic($, 'robotics');
    await $.waitUntilVisible(
      $('PUBLICATIONS ACROSS TOP JOURNALS'),
      timeout: const Duration(seconds: 45),
    );

    // Tap the first ranked journal row to push its detail screen.
    await $(RankedCountList).$(InkWell).first.tap();

    await $.waitUntilVisible(
      $('Most cited publications'),
      timeout: const Duration(seconds: 45),
    );
    expect($('TOTAL PUBLICATIONS'), findsWidgets); // journal-detail StatCard
  });
}
