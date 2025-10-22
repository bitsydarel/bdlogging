import 'package:bdlogging/bdlogging.dart';
import 'package:intl/intl.dart';

/// Represents a person with a name.
/// Used for serialization in logging.
class Person {
  /// The name of the person.
  final String name;

  /// Creates a [Person] instance with the given [name].
  Person(this.name);

  /// Converts this [Person] to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
      };

  /// Creates a [Person] from a JSON map.
  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(json['name'] as String);
  }
}

/// Default implementation of a [BDLogFormatter].
///
/// Format [BDLogRecord] to look like this:
///
/// {time}{level}{message}{error}{stacktrace}
class EncryptedLogFormatter extends BDLogFormatter {
  /// Create [EncryptedLogFormatter].

  /// A password to use for the encryption/decryption.

  final Person x;

  /// Constructs an [EncryptedLogFormatter] with the given [Person] instance.
  /// Prints the hash code of [x] for debugging purposes.
  EncryptedLogFormatter(this.x) {
    print("x hashCode: ${x.hashCode}");
  }

  @override
  String format(final BDLogRecord record) {
    final DateFormat formatter = DateFormat('dd-MM-yyyy H:m:s');
    final String time = formatter.format(record.time);

    final StringBuffer buffer = StringBuffer()
      ..writeln()
      ..write("x=${x.hashCode}")
      ..write(time)
      ..write(' ${record.level.label}: ${record.isFatal ? 'FATAL ' : ''}')
      ..write('${record.message} ');

    if (record.error != null) {
      buffer.writeln(record.error.toString());
    }
    if (record.stackTrace != null) {
      buffer
        ..writeln()
        ..writeln(record.stackTrace.toString());
    }

    return _obfuscateLog(buffer.toString());
  }

  /// Will attempt to obfuscate any sensitive data in msg
  String _obfuscateLog(final String log) {
    // if (kDebugMode) {
    //   return log;
    // }

    String obfuscatedLog = log;
    // remove paswords
    obfuscatedLog = _obfuscateLogWithPattern(
      pattern: _explicitPasswordPattern,
      log: obfuscatedLog,
    );
    // remove api keys
    obfuscatedLog = _obfuscateLogWithPattern(
      pattern: _explicitApiKeyPattern,
      log: obfuscatedLog,
    );
    // remove tokens
    obfuscatedLog = _obfuscateLogWithPattern(
      pattern: _explicitTokenPattern,
      log: obfuscatedLog,
    );
    // remove authorization
    obfuscatedLog = _obfuscateLogWithPattern(
      pattern: _explicitAuthorizationPattern,
      log: obfuscatedLog,
    );
    // remove coordinates
    obfuscatedLog = _obfuscateLogWithPattern(
      pattern: _explicitCoordinatesPattern,
      log: obfuscatedLog,
    );
    return obfuscatedLog;
  }

  String _obfuscateLogWithPattern({
    required final RegExp pattern,
    required final String log,
  }) {
    String obfuscatedMsg = log;
    if (pattern.hasMatch(obfuscatedMsg)) {
      for (final RegExpMatch match in pattern.allMatches(obfuscatedMsg)) {
        obfuscatedMsg = obfuscatedMsg.replaceAllMapped(
          match.group(match.groupCount)!,
          (Match match) => "*" * 6,
        );
      }
    }
    return obfuscatedMsg;
  }

  final RegExp _explicitPasswordPattern = RegExp(
    r'(password|pw)(.*)',
    caseSensitive: false,
    multiLine: true,
  );
  final RegExp _explicitApiKeyPattern = RegExp(
    r'(apiKey|API_KEY|ONESIGNAL_KEY)(.*)',
    caseSensitive: false,
    multiLine: true,
  );
  final RegExp _explicitTokenPattern = RegExp(
    r'(token|accessToken|refreshToken|access_token|refresh_token)(.*)',
    caseSensitive: false,
    multiLine: true,
  );
  final RegExp _explicitAuthorizationPattern = RegExp(
    r'(Iteration number: |Bearer)(.*)',
    caseSensitive: false,
    multiLine: true,
  );

  final RegExp _explicitCoordinatesPattern = RegExp(
    r'(coordinate|features:)(.*)',
    caseSensitive: false,
    multiLine: true,
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': 'EncryptedLogFormatter',
        'x': x.toJson(),
      };

  /// Deserialize from JSON (optional, for isolate usage).
  @override
  EncryptedLogFormatter fromJson(Map<String, dynamic> json) {
    return EncryptedLogFormatter(
        Person.fromJson(json['x'] as Map<String, dynamic>));
  }
}
