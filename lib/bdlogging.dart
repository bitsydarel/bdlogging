library bdlogging;

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:bdlogging/src/bd_cleanable_log_handler.dart';
import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_error.dart';
import 'package:bdlogging/src/bd_log_handler.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:meta/meta.dart';

export 'src/bd_cleanable_log_handler.dart';
export 'src/bd_level.dart';
export 'src/bd_log_error.dart';
export 'src/bd_log_formatter.dart';
export 'src/bd_log_handler.dart';
export 'src/bd_log_record.dart';
export 'src/formatters/default_log_formatter.dart';
export 'src/handlers/console_log_handler.dart';
export 'src/handlers/file_log_handler.dart';
export 'src/handlers/isolate_file_log_handler.dart';

/// `BDLogger` is a singleton class used for logging in Dart/Flutter applications.
///
/// It provides methods to log messages
/// at different levels (debug, info, warning, success, error).
///
/// It supports multiple log handlers to handle log records
/// in different ways (e.g., writing to a file, sending to a server).
///
/// The processing interval and chunk size can be changed dynamically,
/// allowing developers to adjust the logger's performance at runtime.
///
/// The class provides a stream of `BDLogError` that occurred during logging,
/// allowing developers to handle logging errors in a centralized way.
///
/// Here's an example of how to use this class:
///
/// ```dart
/// final logger = BDLogger();
/// logger.addHandler(ConsoleLogHandler());
/// logger.log(BDLevel.info, 'Hello, world!');
/// ```
///
/// If an error occurs while a log handler is processing a log record,
/// the error is caught and added to the error stream. You can listen to
/// this stream to handle logging errors:
///
/// ```dart
/// logger.onError.listen((error) {
///   // Handle the error.
/// });
/// ```
///
/// When you're done with the logger, you should call the `destroy` method
/// to clean up resources:
///
/// ```dart
/// logger.destroy();
/// ```
class BDLogger {
  static BDLogger? _instance;

  /// The default number of log records that are processed at a time.
  static const int defaultProcessingBatchSize = 100;

  /// Returns the singleton instance of the `BDLogger` class.
  factory BDLogger() {
    return _instance ??= BDLogger.private(
      <BDLogHandler>{},
      StreamController<BDLogError>.broadcast(),
    );
  }

  /// Private constructor used to create the singleton instance of the class.
  /// This constructor is marked as `@visibleForTesting` to allow it
  /// to be accessed in tests.
  @visibleForTesting
  BDLogger.private(
    this._handlers,
    this._errorController, [
    this._processingBatchSize = defaultProcessingBatchSize,
  ]) {
    _registerLogProcessingTimer();
  }

  /// A completer that is used to control the processing of log records.
  @visibleForTesting
  Completer<void>? processingTask;

  int _processingBatchSize;

  final Set<BDLogHandler> _handlers;

  final StreamController<BDLogError> _errorController;

  /// A queue of log records that are waiting to be processed.
  @visibleForTesting
  final Queue<BDLogRecord> recordQueue = Queue<BDLogRecord>();

  /// Returns a stream that emits [BDLogError] instances
  /// whenever an error occurs during logging.
  Stream<BDLogError> get onError => _errorController.stream;

  /// Returns the number of log records that are processed at a time.
  int get processingBatchSize => _processingBatchSize;

  /// Changes the number of log records that are processed at a time.
  /// If the new value is different from the current value,
  /// the processing timer is restarted.
  set processingBatchSize(int value) {
    if (_processingBatchSize != value) {
      _processingBatchSize = value;
    }
  }

  /// Returns a list of the log handlers that are currently added to the logger.
  List<BDLogHandler> get handlers {
    return UnmodifiableListView<BDLogHandler>(_handlers);
  }

  /// Adds a log handler to the logger.
  /// The handler will be used to process log records.
  void addHandler(final BDLogHandler handler) {
    final bool wasEmpty = _handlers.isEmpty;
    _handlers.add(handler);

    if (wasEmpty) {
      unawaited(_registerLogProcessingTimer());
    }
  }

  /// Removes a log handler from the logger.
  /// The handler will no longer be used to process log records.
  bool removeHandler(final BDLogHandler handler) {
    return _handlers.remove(handler);
  }

  /// Logs a message at the debug level.
  /// The message can optionally be associated with an error and a stack trace.
  void debug(
    final String message, {
    final dynamic error,
    final bool? isFatal,
    final StackTrace? stackTrace,
    final String? tag,
  }) {
    log(
      BDLevel.debug,
      tag != null ? '$tag: $message' : message,
      error: error,
      isFatal: isFatal,
      stackTrace: stackTrace,
    );
  }

  /// Logs a message at the info level.
  void info(final String message, {final String? tag}) {
    log(BDLevel.info, tag != null ? '$tag: $message' : message);
  }

  /// Logs a message at the warning level.
  /// The message can optionally be associated with an error and a stack trace.
  void warning(
    final String message, {
    final String? tag,
    final dynamic error,
    final bool? isFatal,
    final StackTrace? stackTrace,
  }) {
    log(
      BDLevel.warning,
      tag != null ? '$tag: $message' : message,
      error: error,
      isFatal: isFatal,
      stackTrace: stackTrace,
    );
  }

  /// Logs a message at the success level.
  void success(final String message, {final String? tag}) {
    log(BDLevel.success, tag != null ? '$tag: $message' : message);
  }

  /// Logs a message at the error level.
  /// The message is associated with an error and can optionally
  /// be associated with a stack trace.
  void error(
    final String message,
    final Object error, {
    final bool? isFatal,
    final StackTrace? stackTrace,
    final String? tag,
  }) {
    log(
      BDLevel.error,
      tag != null ? '$tag: $message' : message,
      error: error,
      stackTrace: stackTrace,
      isFatal: isFatal,
    );
  }

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
    final bool? isFatal,
  }) {
    final BDLogRecord newLogRecord = BDLogRecord(
      level,
      message,
      error: error,
      stackTrace: stackTrace,
      isFatal: isFatal ?? false,
    );

    recordQueue.add(newLogRecord);

    final Completer<void>? task = processingTask;

    if (task == null || task.isCompleted) {
      unawaited(_registerLogProcessingTimer());
    }
  }

  /// Destroys the singleton instance of the `BDLogger` class.
  /// This also calls the `clean` method on every [BDCleanableLogHandler].
  Future<void> destroy() async {
    _completeProcessingTask();

    while (recordQueue.isNotEmpty) {
      await _processLogRecord(recordQueue.removeFirst());
    }

    try {
      for (final BDCleanableLogHandler handler
          in handlers.whereType<BDCleanableLogHandler>()) {
        await handler.clean();
      }
    } on Object catch (error, stackTrace) {
      _errorController.add(BDLogError(error, stackTrace));
    }

    _handlers.clear();

    _instance = null;

    await _errorController.sink.close();
    return _errorController.close();
  }

  Future<void> _registerLogProcessingTimer() async {
    final Completer<void> resolvedTask = processingTask?.isCompleted ?? true
        ? Completer<void>()
        : processingTask!;
    processingTask = resolvedTask;

    if (_handlers.isNotEmpty) {
      final int recordsToProcess =
          min(recordQueue.length, _processingBatchSize);

      for (int i = 0; i < recordsToProcess; i++) {
        if (recordQueue.isNotEmpty) {
          await _processLogRecord(recordQueue.removeFirst());
        }
      }

      if (recordQueue.isNotEmpty) {
        return _registerLogProcessingTimer();
      }
    }

    if (!resolvedTask.isCompleted) {
      resolvedTask.complete();
    }
  }

  Future<void> _processLogRecord(final BDLogRecord record) {
    return Future.forEach(handlers, (BDLogHandler handler) async {
      if (handler.supportLevel(record.level)) {
        try {
          await handler.handleRecord(record);
        } on Object catch (error, stackTrace) {
          _errorController.add(BDLogError(error, stackTrace));
          // note: Added so that in debug run user could see error produced by
          // handlers while handling a log record.
          // this code is removed when compiling to release build.
          assert(
            false,
            '${handler.runtimeType} could not process '
            '$record\n$error\n${stackTrace.toString()}',
          );
        }
      }
    });
  }

  void _completeProcessingTask() {
    final Completer<void>? currentTask = processingTask;
    if (currentTask != null && !currentTask.isCompleted) {
      currentTask.complete();
    }
  }
}
