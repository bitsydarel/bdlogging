import 'package:bdlogging/src/bd_level.dart';
import 'package:meta/meta.dart';

/// Logging record.
@immutable
class BDLogRecord {
  /// Create a new Logging record.
  /// Logging record's [level] is required.
  /// Logging record's [message] is required.
  ///
  BDLogRecord(
    this.level,
    this.message, {
    this.error,
    this.stackTrace,
    this.isFatalError = false,
  }) : time = DateTime.now();

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

  /// Logging record's a fatal error.
  final bool isFatalError;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BDLogRecord &&
          runtimeType == other.runtimeType &&
          level == other.level &&
          message == other.message &&
          error == other.error &&
          time == other.time &&
          stackTrace == other.stackTrace;

  @override
  int get hashCode =>
      level.hashCode ^
      message.hashCode ^
      error.hashCode ^
      time.hashCode ^
      stackTrace.hashCode;

  @override
  String toString() {
    return 'BDLogRecord{level: $level, message: $message, error: $error, '
        'time: $time, stackTrace: $stackTrace, fatalError: $isFatalError}';
  }
}
