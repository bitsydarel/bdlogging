import 'package:bdlogging/src/security/sensitive_data_matcher.dart';
import 'package:test/test.dart';

List<String> _extractMatches(
  SensitiveDataMatcher matcher,
  String message,
) {
  return matcher
      .findMatches(message)
      .map(
        (SensitiveMatch match) => message.substring(match.start, match.end),
      )
      .toList();
}

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

    test('finds password variants with quotes and separators', () {
      final SensitiveDataMatcher matcher = RegexSensitiveDataMatcher();
      const String message =
          'password="secret" passwd:pass1 PWD=pass2 passcode=\'code1\'';
      final List<String> matches = _extractMatches(matcher, message);

      expect(
        matches,
        containsAll(<String>['secret', 'pass1', 'pass2', 'code1']),
      );
      expect(matches, hasLength(4));
    });

    test('finds authorization bearer tokens with flexible whitespace', () {
      final SensitiveDataMatcher matcher = RegexSensitiveDataMatcher();
      const String message = 'authorization \t=\nBearer\tabc123';
      final List<SensitiveMatch> matches =
          matcher.findMatches(message).toList();

      expect(matches, hasLength(1));
      expect(
        message.substring(matches.first.start, matches.first.end),
        equals('abc123'),
      );
    });

    test('finds authorization basic credentials', () {
      final SensitiveDataMatcher matcher = RegexSensitiveDataMatcher();
      const String message = 'Authorization: Basic dXNlcjpwYXNz';
      final List<SensitiveMatch> matches =
          matcher.findMatches(message).toList();

      expect(matches, hasLength(1));
      expect(
        message.substring(matches.first.start, matches.first.end),
        equals('dXNlcjpwYXNz'),
      );
    });

    test('finds authorization basic credentials in quoted values', () {
      final SensitiveDataMatcher matcher = RegexSensitiveDataMatcher();
      const String message = 'authorization = "Basic dXNlcjpwYXNz"';
      final List<String> matches = _extractMatches(matcher, message);

      expect(matches, hasLength(1));
      expect(matches.first, equals('dXNlcjpwYXNz'));
    });

    test('finds authorization bearer tokens in quoted values', () {
      final SensitiveDataMatcher matcher = RegexSensitiveDataMatcher();
      const String message = '"Authorization": "Bearer abc123"';
      final List<SensitiveMatch> matches =
          matcher.findMatches(message).toList();

      expect(matches, hasLength(1));
      expect(
        message.substring(matches.first.start, matches.first.end),
        equals('abc123'),
      );
    });

    test('finds api key variants', () {
      final SensitiveDataMatcher matcher = RegexSensitiveDataMatcher();
      const String message = 'X-API-KEY: key-123';
      final List<SensitiveMatch> matches =
          matcher.findMatches(message).toList();

      expect(matches, hasLength(1));
      expect(
        message.substring(matches.first.start, matches.first.end),
        equals('key-123'),
      );
    });

    test('finds api key and credential variants', () {
      final SensitiveDataMatcher matcher = RegexSensitiveDataMatcher();
      const String message =
          'api key=ak x-api-key=xa client secret=cs private key=pk '
          'access key=ac credential=cr credentials=crs secret=sec';
      final List<String> matches = _extractMatches(matcher, message);

      expect(
        matches,
        containsAll(<String>['ak', 'xa', 'cs', 'pk', 'ac', 'cr', 'crs', 'sec']),
      );
    });

    test('finds token variants with mixed casing', () {
      final SensitiveDataMatcher matcher = RegexSensitiveDataMatcher();
      const String message = 'refresh_token=ref123 idToken=abc456';
      final List<String> matches = _extractMatches(matcher, message);

      expect(matches, containsAll(<String>['ref123', 'abc456']));
    });

    test('finds full token key variants', () {
      final SensitiveDataMatcher matcher = RegexSensitiveDataMatcher();
      const String message =
          'auth token=auth123 access_token=acc123 refresh-token=ref123 '
          'idToken=id456 session token=sess789 jwt=abc.def.ghi';
      final List<String> matches = _extractMatches(matcher, message);

      expect(
        matches,
        containsAll(
          <String>[
            'auth123',
            'acc123',
            'ref123',
            'id456',
            'sess789',
            'abc.def.ghi'
          ],
        ),
      );
    });

    test('splits query strings on ampersand', () {
      final SensitiveDataMatcher matcher = RegexSensitiveDataMatcher();
      const String message = 'token=abc&api_key=def&other=ok';
      final List<String> matches = _extractMatches(matcher, message);

      expect(matches, containsAll(<String>['abc', 'def']));
      expect(matches, isNot(contains('ok')));
      expect(matches.every((String value) => !value.contains('&')), isTrue);
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

    test('does not match non-sensitive keys or empty values', () {
      final SensitiveDataMatcher matcher = RegexSensitiveDataMatcher();

      expect(matcher.findMatches('tokenize=abc'), isEmpty);
      expect(matcher.findMatches('password='), isEmpty);
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
