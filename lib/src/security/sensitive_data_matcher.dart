import 'package:meta/meta.dart';

/// Represents a sensitive substring within a message.
@immutable
class SensitiveMatch {
  /// Creates a match with [start] and [end] indices.
  const SensitiveMatch({required this.start, required this.end});

  /// Start index of the sensitive substring.
  final int start;

  /// End index (exclusive) of the sensitive substring.
  final int end;
}

/// Finds sensitive ranges inside a message.
abstract class SensitiveDataMatcher {
  /// Returns the sensitive ranges inside the message.
  Iterable<SensitiveMatch> findMatches(String message);

  /// Optional disposal hook for matcher resources.
  void dispose() {}
}

/// A regex pattern with an optional capture `group`.
@immutable
class SensitivePattern {
  /// Creates a pattern that extracts the sensitive group.
  const SensitivePattern(this.regex, {this.group = 0});

  /// Pattern used to locate sensitive information.
  final RegExp regex;

  /// Capture group that contains the sensitive value.
  final int group;
}

/// Default matcher that detects passwords, tokens, emails, and phone numbers.
class RegexSensitiveDataMatcher extends SensitiveDataMatcher {
  /// Creates a matcher with optional [patterns].
  RegexSensitiveDataMatcher({List<SensitivePattern>? patterns})
      : _patterns = patterns;

  final List<SensitivePattern>? _patterns;

  /// Built-in patterns used when no custom patterns are supplied.
  static final List<SensitivePattern> defaultPatterns = <SensitivePattern>[
    SensitivePattern(
      RegExp(
        r'''["']?(?:password|passwd|pwd|passcode)["']?\s*[:=]\s*["']?([^\s,;"'&]+)["']?''',
        caseSensitive: false,
      ),
      group: 1,
    ),
    SensitivePattern(
      RegExp(
        r'''["']?authorization["']?\s*[:=]\s*["']?(?:bearer|token)\s+["']?([^\s,;"'&]+)["']?''',
        caseSensitive: false,
      ),
      group: 1,
    ),
    SensitivePattern(
      RegExp(
        r'''["']?authorization["']?\s*[:=]\s*["']?basic\s+["']?([^\s,;"'&]+)["']?''',
        caseSensitive: false,
      ),
      group: 1,
    ),
    SensitivePattern(
      RegExp(
        r'''["']?(?:token|auth[\s_-]*token|access[\s_-]*token|'''
        r'''refresh[\s_-]*token|id[\s_-]*token|session[\s_-]*token|jwt)["']?'''
        r'''\s*[:=]\s*["']?([^\s,;"'&]+)["']?''',
        caseSensitive: false,
      ),
      group: 1,
    ),
    SensitivePattern(
      RegExp(
        r'''["']?(?:api[\s_-]*key|x[\s_-]*api[\s_-]*key|'''
        r'''client[\s_-]*secret|client[\s_-]*key|secret[\s_-]*key|'''
        r'''private[\s_-]*key|access[\s_-]*key)["']?'''
        r'''\s*[:=]\s*["']?([^\s,;"'&]+)["']?''',
        caseSensitive: false,
      ),
      group: 1,
    ),
    SensitivePattern(
      RegExp(
        r'''["']?(?:credential(?:s)?|secret)["']?\s*[:=]\s*["']?([^\s,;"'&]+)["']?''',
        caseSensitive: false,
      ),
      group: 1,
    ),
    SensitivePattern(
      RegExp(
        r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
        caseSensitive: false,
      ),
    ),
    SensitivePattern(
      RegExp(
        r'(?:\+?\d{1,3}[\s.-]?)?(?:\(?\d{2,4}\)?[\s.-]?)?'
        r'\d{3}[\s.-]?\d{4}',
        caseSensitive: false,
      ),
    ),
  ];

  @override
  Iterable<SensitiveMatch> findMatches(String message) {
    final List<SensitiveMatch> matches = <SensitiveMatch>[];
    for (final SensitivePattern pattern in _patterns ?? defaultPatterns) {
      for (final RegExpMatch match in pattern.regex.allMatches(message)) {
        final int start = _matchStart(match, pattern.group);
        final int end = _matchEnd(match, pattern.group);
        if (start >= 0 && end > start) {
          matches.add(SensitiveMatch(start: start, end: end));
        }
      }
    }

    matches.sort((SensitiveMatch a, SensitiveMatch b) {
      final int startCompare = a.start.compareTo(b.start);
      if (startCompare != 0) {
        return startCompare;
      }
      return a.end.compareTo(b.end);
    });

    return matches;
  }

  int _matchStart(RegExpMatch match, int group) {
    if (group == 0) {
      return match.start;
    }
    return _matchGroupStart(match, group);
  }

  int _matchEnd(RegExpMatch match, int group) {
    if (group == 0) {
      return match.end;
    }
    return _matchGroupEnd(match, group);
  }

  int _matchGroupStart(RegExpMatch match, int group) {
    final String? fullMatch = match.group(0);
    final String? groupValue = match.group(group);
    if (fullMatch == null || groupValue == null) {
      return -1;
    }
    final int offset = fullMatch.indexOf(groupValue);
    if (offset < 0) {
      return -1;
    }
    return match.start + offset;
  }

  int _matchGroupEnd(RegExpMatch match, int group) {
    final int start = _matchGroupStart(match, group);
    if (start < 0) {
      return -1;
    }
    final String? groupValue = match.group(group);
    if (groupValue == null) {
      return -1;
    }
    return start + groupValue.length;
  }
}
