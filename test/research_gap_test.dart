import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/models/models.dart';
import 'package:journal_trend_analyzer/services/research_gap.dart';

Work _w({int? year, int cites = 0}) =>
    Work(title: 'x', citedByCount: cites, authors: const [], publicationYear: year);

void main() {
  group('ResearchGap.isEmerging', () {
    const now = 2026;

    test('recent + lightly cited → emerging', () {
      expect(ResearchGap.isEmerging(_w(year: 2025, cites: 3), currentYear: now), isTrue);
    });

    test('old paper → not emerging', () {
      expect(ResearchGap.isEmerging(_w(year: 2010, cites: 3), currentYear: now), isFalse);
    });

    test('recent but highly cited → not emerging', () {
      expect(
        ResearchGap.isEmerging(_w(year: 2025, cites: 5000), currentYear: now),
        isFalse,
      );
    });

    test('missing year → not emerging', () {
      expect(ResearchGap.isEmerging(_w(cites: 1), currentYear: now), isFalse);
    });

    test('countEmerging counts only matching works', () {
      final works = [
        _w(year: 2025, cites: 1), // emerging
        _w(year: 2024, cites: 2), // emerging
        _w(year: 2000, cites: 1), // too old
        _w(year: 2025, cites: 99), // too cited
      ];
      expect(ResearchGap.countEmerging(works, currentYear: now), 2);
    });
  });
}
