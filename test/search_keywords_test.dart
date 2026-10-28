import 'package:flutter_test/flutter_test.dart';
import 'package:bookswaphub/core/utils/search_keywords.dart';

void main() {
  group('buildSearchKeywords', () {
    test('creates lowercase prefixes of length 2..6', () {
      final k = buildSearchKeywords('Clean Code', 'Robert Martin');
      expect(k, containsAll(['cl', 'cle', 'clea', 'clean', 'co', 'cod', 'code']));
      expect(k.every((e) => e == e.toLowerCase()), isTrue);
    });

    test('adds whole long words and never exceeds 40 entries', () {
      final k = buildSearchKeywords('Extraordinarily Comprehensive Encyclopedia Volume', 'Alexander Montgomery');
      expect(k, contains('extraordinarily'));
      expect(k.length, lessThanOrEqualTo(40));
    });

    test('ignores punctuation and single letters', () {
      final k = buildSearchKeywords('A Tale!', '');
      expect(k, isNot(contains('a')));
      expect(k, contains('ta'));
    });
  });

  group('queryKeyword / matchesQuery', () {
    test('returns null for empty input', () {
      expect(queryKeyword('   '), isNull);
    });

    test('truncates the first word to 6 characters', () {
      expect(queryKeyword('Programming'), 'progra');
      expect(queryKeyword('code'), 'code');
    });

    test('matches only when all typed words appear', () {
      expect(matchesQuery('clean code', 'Clean Code', 'Robert Martin'), isTrue);
      expect(matchesQuery('clean java', 'Clean Code', 'Robert Martin'), isFalse);
    });
  });
}
