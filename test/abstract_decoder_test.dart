import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/services/abstract_decoder.dart';

void main() {
  group('reconstructAbstract', () {
    test('returns null for null input', () {
      expect(reconstructAbstract(null), isNull);
    });

    test('returns null for empty map', () {
      expect(reconstructAbstract(<String, dynamic>{}), isNull);
    });

    test('reconstructs words in positional order', () {
      final inverted = <String, dynamic>{
        'Deep': [0],
        'learning': [1],
        'models': [2],
      };
      expect(reconstructAbstract(inverted), 'Deep learning models');
    });

    test('handles repeated words at multiple positions', () {
      final inverted = <String, dynamic>{
        'the': [0, 2],
        'cat': [1],
        'sat': [3],
      };
      expect(reconstructAbstract(inverted), 'the cat the sat');
    });

    test('orders correctly when map keys are out of order', () {
      final inverted = <String, dynamic>{
        'world': [1],
        'hello': [0],
      };
      expect(reconstructAbstract(inverted), 'hello world');
    });
  });
}
