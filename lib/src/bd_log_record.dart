import 'package:bdlogging/src/bd_level.dart';
import 'package:meta/meta.dart';

/// Logging record.
@immutable
class BDLogRecord {
  /// Create a new Logging record.
  /// Logging record's [level] is required.
  /// Logging record's [message] is required.
  BDLogRecord(
    this.level,
    this.message, {
    this.error,
    this.stackTrace,
    this.isFatal = false,
  })  : time = DateTime.now(),
        assert(
          (isFatal && error != null) ||
              (!isFatal && error != null) ||
              error == null,
          'isFatal can only be used with error',
        );

  /// Logging record's logging Level.
  final BDLevel level;

  /// Logging record's message.
  final String message;

  /// Logging record's Error.
  final Object? error;

  /// Logging record's time of creation.
  final DateTime time;

  /// Logging record's stacktrace.
  final StackTrace? stackTrace;

  /// Logging record's error's fatal.
  final bool isFatal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BDLogRecord &&
          runtimeType == other.runtimeType &&
          level == other.level &&
          message == other.message &&
          error == other.error &&
          time == other.time &&
          stackTrace == other.stackTrace &&
          isFatal == other.isFatal;

  @override
  int get hashCode =>
      level.hashCode ^
      message.hashCode ^
      error.hashCode ^
      time.hashCode ^
      stackTrace.hashCode ^
      isFatal.hashCode;

  @override
  String toString() {
    return 'LogRecord{level: $level, message: $message, error: $error, '
        'time: $time, stackTrace: $stackTrace, isFatal: $isFatal}';
  }
}
