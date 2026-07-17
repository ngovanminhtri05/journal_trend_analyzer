import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/models/models.dart';
import 'package:journal_trend_analyzer/services/trend_classifier.dart';

/// Convenience: a publication_year bucket.
GroupByItem _yb(int year, int count) =>
    GroupByItem(key: '$year', keyDisplayName: '$year', count: count);

void main() {
  group('computeTrendSlope', () {
    test('returns 0 for fewer than two points', () {
      expect(computeTrendSlope(const {}), 0);
      expect(computeTrendSlope(const {2020: 10}), 0);
    });

    test('positive slope for an increasing series', () {
      expect(
        computeTrendSlope(const {2018: 10, 2019: 20, 2020: 30}),
        greaterThan(0),
      );
    });

    test('negative slope for a decreasing series', () {
      expect(
        computeTrendSlope(const {2018: 30, 2019: 20, 2020: 10}),
        lessThan(0),
      );
    });

    test('zero slope for a flat series', () {
      expect(computeTrendSlope(const {2018: 10, 2019: 10, 2020: 10}), 0);
    });

    test('exact least-squares slope', () {
      // 10,20,30 over 2018–2020 → slope = 10 publications/year.
      expect(
        computeTrendSlope(const {2018: 10, 2019: 20, 2020: 30}),
        closeTo(10, 1e-9),
      );
    });
  });

  group('classifyTrend', () {
    test('null when fewer than two usable years', () {
      expect(classifyTrend(const []), isNull);
      expect(classifyTrend([_yb(2020, 5)]), isNull);
      // Non-numeric keys are dropped, leaving < 2 usable years.
      expect(
        classifyTrend([
          GroupByItem(key: 'NA', keyDisplayName: 'NA', count: 5),
          GroupByItem(key: 'x', keyDisplayName: 'x', count: 3),
        ]),
        isNull,
      );
    });

    test('emerging for a strong upward trend', () {
      final c = classifyTrend([
        _yb(2019, 10),
        _yb(2020, 20),
        _yb(2021, 30),
        _yb(2022, 40),
      ]);
      expect(c, isNotNull);
      expect(c!.category, TrendCategory.emerging);
      expect(c.fromYear, 2019);
      expect(c.toYear, 2022);
    });

    test('declining for a downward trend', () {
      final c = classifyTrend([
        _yb(2019, 40),
        _yb(2020, 30),
        _yb(2021, 20),
        _yb(2022, 10),
      ]);
      expect(c!.category, TrendCategory.declining);
    });

    test('mature for a flat trend (within ±5%/yr)', () {
      final c = classifyTrend([
        _yb(2019, 100),
        _yb(2020, 101),
        _yb(2021, 99),
        _yb(2022, 100),
      ]);
      expect(c!.category, TrendCategory.mature);
    });

    test('scale-independent: small and huge topics get the same verdict', () {
      final small = classifyTrend([
        _yb(2019, 10),
        _yb(2020, 15),
        _yb(2021, 20),
        _yb(2022, 25),
      ]);
      final huge = classifyTrend([
        _yb(2019, 10000),
        _yb(2020, 15000),
        _yb(2021, 20000),
        _yb(2022, 25000),
      ]);
      expect(small!.category, TrendCategory.emerging);
      expect(huge!.category, TrendCategory.emerging);
    });

    test('uses only the most recent window of years', () {
      // Old declining block, then a recent rise — window=3 should see only the
      // recent rise and classify it emerging.
      final items = [
        _yb(2010, 100),
        _yb(2011, 90),
        _yb(2012, 80),
        _yb(2020, 10),
        _yb(2021, 20),
        _yb(2022, 30),
      ];
      final c = classifyTrend(items, window: 3);
      expect(c!.fromYear, 2020);
      expect(c.toYear, 2022);
      expect(c.category, TrendCategory.emerging);
    });
  });
}
