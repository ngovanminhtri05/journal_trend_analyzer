import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/widgets/widgets.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

/// TC2 (Topic Search overview) and TC3 (Publication Detail).
///
/// Notes on the finders:
///  - `StatCard` renders its label upper-cased, so metric assertions use the
///    on-screen form (e.g. "TOTAL PUBLICATIONS").
///  - TC2 checks the Home overview. TC3 opens a publication's detail from a
///    journal's most-cited list — a chart-free screen whose first paper card is
///    above the fold, so the tap is deterministic (the Home overview's
///    most-influential card sits below a fixed-height chart and can be absent
///    when the topic has no cited works).
void main() {
  patrolTest('TC2: searching a topic shows the overview', ($) async {
    await pumpShell($);
    await searchTopic($, 'machine learning');

    // Success state: the trend chart heading renders above the fold.
    await $.waitUntilVisible(
      $('Publications over time'),
      timeout: const Duration(seconds: 45),
    );

    // The headline metrics grid renders just below the chart.
    await revealByScrolling($, $('TOTAL PUBLICATIONS'));
    expect($('TOTAL PUBLICATIONS'), findsWidgets);
    expect($('MOST ACTIVE YEAR'), findsWidgets);
  });

  patrolTest('TC3: opening a publication shows its detail', ($) async {
    await pumpShell($);
    await openTab($, 'Journals');
    await searchTopic($, 'robotics');
    await $.waitUntilVisible(
      $('PUBLICATIONS ACROSS TOP JOURNALS'),
      timeout: const Duration(seconds: 45),
    );

    // Open the top journal, then its most-cited publication.
    await $(RankedCountList).$(InkWell).first.tap();
    await $.waitUntilVisible(
      $('Most cited publications'),
      timeout: const Duration(seconds: 45),
    );
    await $(PaperCard).first.tap();

    // Publication detail is pushed on top.
    await $.waitUntilVisible(
      $('Authors'),
      timeout: const Duration(seconds: 30),
    );
    expect($('Publication'), findsWidgets); // detail app-bar title
    expect($('Abstract'), findsWidgets);
  });
}
