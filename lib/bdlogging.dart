library bdlogging;

import 'dart:async';
import 'dart:collection';

import 'package:bdlogging/src/bd_cleanable_log_handler.dart';
import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_handler.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:meta/meta.dart';

export 'src/bd_cleanable_log_handler.dart';
export 'src/bd_level.dart';
export 'src/bd_log_formatter.dart';
export 'src/bd_log_handler.dart';
export 'src/bd_log_record.dart';
export 'src/formatters/default_log_formatter.dart';
export 'src/handlers/console_log_handler.dart';
export 'src/handlers/file_log_handler.dart';

/// [BDLogger] used to log messages.
class BDLogger {
  /// Get an instance of the logger with the following name
  factory BDLogger() {
    return _instance ??= BDLogger.private(
      'FlutterLogger',
      <BDLogHandler>[],
      StreamController<BDLogRecord>.broadcast(),
    );
  }

  /// Create a new instance of the Logger.
  @visibleForTesting
  BDLogger.private(this.name, this._handlers, this._logRecordController) {
    _logRecordController.stream.listen(_handleLogRecord);
  }

  static BDLogger? _instance;

  /// [BDLogger]'s name.
  final String name;

  final List<BDLogHandler> _handlers;

  final StreamController<BDLogRecord> _logRecordController;

  /// Get list of [BDLogHandler] available in this logger.
  List<BDLogHandler> get handlers {
    return UnmodifiableListView<BDLogHandler>(_handlers);
  }

  /// Add a new [BDLogHandler] handler to the Logger.
  void addHandler(final BDLogHandler handler) {
    _handlers.add(handler);
  }

  /// Remove a handler from the list of handlers.
  bool removeHandler(final BDLogHandler handler) {
    return _handlers.remove(handler);
  }

  /// Log a message at [BDLevel.debug]
  void debug(
    final String message, {
    final dynamic error,
    final StackTrace? stackTrace,
    final String? tag,
  }) {
    log(
      BDLevel.debug,
      tag != null ? '$tag: $message' : message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a message at [BDLevel.info].
  void info(final String message, {final String? tag}) {
    log(BDLevel.info, tag != null ? '$tag: $message' : message);
  }

  /// Log a message at [BDLevel.warning]
  void warning(
    final String message, {
    final String? tag,
    final dynamic error,
    final StackTrace? stackTrace,
  }) {
    log(
      BDLevel.warning,
      tag != null ? '$tag: $message' : message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a message at [BDLevel.success].
  void success(final String message, {final String? tag}) {
    log(BDLevel.success, tag != null ? '$tag: $message' : message);
  }

  /// Log a message at [BDLogger.error]
  void error(
    final String message,
    final Object error, {
    final StackTrace? stackTrace,
    final String? tag,
  }) {
    log(
      BDLevel.error,
      tag != null ? '$tag: $message' : message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Adds a log record for a [message] at a particular [BDLevel] if
  ///
  /// Use this method to create log entries for user-defined levels. To record a
  /// message at a predefined level (e.g. [BDLevel.info], [BDLevel.warning])
  /// you can use their specialized methods instead (e.g. [info], [warning],
  /// etc).
  ///
  /// The log record will also contain a field for the zone in which this call
  /// was made. This can be advantageous if a log listener wants to handler
  /// records of different zones differently (e.g. group log records by HTTP
  /// request if each HTTP request handler runs in it's own zone).
  void log(
    final BDLevel level,
    final String message, {
    final Object? error,
    final StackTrace? stackTrace,
  }) {
    final BDLogRecord record = BDLogRecord(
      level,
      message,
      error: error,
      stackTrace: stackTrace,
    );

    _logRecordController.add(record);
  }

  /// Destroy the current instance of [BDLogger].
  ///
  /// It also call clean on every [BDCleanableLogHandler].
  Future<void> destroy() async {
    await _logRecordController.sink.close();

    for (final BDCleanableLogHandler handler
        in _handlers.whereType<BDCleanableLogHandler>()) {
      await handler.clean();
    }

    _handlers.clear();

    _instance = null;

    return _logRecordController.close();
  }

  void _handleLogRecord(final BDLogRecord record) {
    for (final BDLogHandler handler in _handlers) {
      if (handler.supportLevel(record.level)) {
        try {
          handler.handleRecord(record);
        } on Exception catch (ex) {
          // note: Added so that in debug run user could see error produced by
          // handlers while handling a log record.
          // this code is removed when compiling to release build.
          assert(
            false,
            '$name $ex\n${handler.runtimeType} could not process $record',
          );
        }
      }
    }
  }
}
