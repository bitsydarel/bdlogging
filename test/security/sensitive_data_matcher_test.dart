import 'package:bdlogging/src/security/sensitive_data_matcher.dart';
import 'package:test/test.dart';

void main() {
  group('RegexSensitiveDataMatcher', () {
    test('finds password value', () {
      final SensitiveDataMatcher matcher = RegexSensitiveDataMatcher();
      final List<SensitiveMatch> matches =
          matcher.findMatches('password=supersecret').toList();

      expect(matches, hasLength(1));
      expect(matches.first.start, greaterThan(0));
      expect(matches.first.end, greaterThan(matches.first.start));
    });

    test('finds token values', () {
      final SensitiveDataMatcher matcher = RegexSensitiveDataMatcher();
      final List<SensitiveMatch> matches =
          matcher.findMatches('token=abc123').toList();

      expect(matches, hasLength(1));
    });

    test('finds email and phone patterns', () {
      final SensitiveDataMatcher matcher = RegexSensitiveDataMatcher();
      final List<SensitiveMatch> matches = matcher
          .findMatches('Contact: qa@example.com, +1 415-555-1212')
          .toList();

      expect(matches.length, greaterThanOrEqualTo(2));
    });

    test('returns empty list when no matches found', () {
      final SensitiveDataMatcher matcher = RegexSensitiveDataMatcher();

      expect(matcher.findMatches('hello world'), isEmpty);
    });

    test('returns matches in order from left to right', () {
      final SensitiveDataMatcher matcher = RegexSensitiveDataMatcher();
      const String message = 'email=a@b.com password=secret';
      final List<SensitiveMatch> matches =
          matcher.findMatches(message).toList();
      final List<int> expectedStarts = <int>[
        message.indexOf('a@b.com'),
        message.indexOf('secret'),
      ];

      expect(matches, hasLength(2));
      expect(matches.first.start, lessThan(matches.last.start));
      expect(matches.map((SensitiveMatch match) => match.start).toList(),
          orderedEquals(expectedStarts));
    });

    test('handles overlapping matches deterministically', () {
      final SensitiveDataMatcher matcher = RegexSensitiveDataMatcher(
        patterns: <SensitivePattern>[
          SensitivePattern(RegExp(r'token=([^\s]+)'), group: 1),
          SensitivePattern(RegExp('token=abc123')), // overlaps full string
        ],
      );
      final List<SensitiveMatch> matches =
          matcher.findMatches('token=abc123').toList();

      expect(matches, hasLength(2));
      expect(matches.first.start, equals(0));
      expect(matches.last.start, equals(6));
    });
  });
}
