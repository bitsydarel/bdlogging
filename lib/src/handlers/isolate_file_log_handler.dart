import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';

import 'package:bdlogging/src/bd_cleanable_log_handler.dart';
import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:bdlogging/src/handlers/file_log_handler.dart';
import 'package:meta/meta.dart';

/// Function signature for logging operations.
/// Used for dependency injection to enable testing.
typedef LogFunction = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

/// A implementation of [BDCleanableLogHandler]
/// that write [BDLogRecord] to files in a different isolate.
class IsolateFileLogHandler implements BDCleanableLogHandler {
  /// Create a new instance of [IsolateFileLogHandler].
  ///
  /// [logNamePrefix] will be used as prefix for each log file created by the
  /// instance of this [IsolateFileLogHandler].
  ///
  /// It's recommended that the [logNamePrefix] be unique in the app.
  ///
  /// [maxLogSizeInMb] will be used to be deleted old log files.
  /// If in the [logFileDirectory] there's files with prefix [logNamePrefix]
  /// and the count of files is greater than [maxFilesCount], older files will
  /// be deleted.
  ///
  /// [logFileDirectory] is the directory where log files will be stored.
  ///
  /// We assume that the [logFileDirectory] provided exist in the file system.
  ///
  /// [supportedLevels] will be used to discard [BDLogRecord] with
  /// [BDLevel] lower than [supportedLevels].
  ///
  /// [logFunction] is used for internal logging. Defaults to [developer.log].
  /// Can be overridden for testing purposes.
  IsolateFileLogHandler(
    this.logFileDirectory, {
    this.maxFilesCount = 5,
    this.logNamePrefix = '_log',
    this.maxLogSizeInMb = 5,
    this.supportedLevels = const <BDLevel>[
      BDLevel.warning,
      BDLevel.success,
      BDLevel.error,
    ],
    LogFunction? logFunction,
  })  : _logFunction = logFunction ?? _defaultLog,
        assert(logNamePrefix.isNotEmpty, 'logNamePrefix should not be empty'),
        assert(
          maxLogSizeInMb > 0,
          'maxLogSizeInMb should not be lower than zero',
        ),
        assert(
          maxFilesCount > 0,
          'maxFilesCount should be greater than zero',
        ) {
    _workerSendPort = _startLogging();
  }

  /// Default log function that delegates to [developer.log].
  static void _defaultLog(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(message, error: error, stackTrace: stackTrace);
  }

  /// Directory where to store the log files.
  final Directory logFileDirectory;

  /// Maximum count of files to keep.
  ///
  /// will be used to deleted old log files.
  /// If in the [logFileDirectory] there's files with prefix [logNamePrefix]
  /// and the count of files is greater than [maxFilesCount],
  /// older files will be deleted.
  final int maxFilesCount;

  /// Prefix of each log files created by this [IsolateFileLogHandler].
  final String logNamePrefix;

  /// Maximum size of a log file in MB.
  final int maxLogSizeInMb;

  /// Supported [BDLevel] of [BDLogRecord].
  final List<BDLevel> supportedLevels;

  /// The log function used for internal logging.
  final LogFunction _logFunction;

  Isolate? _isolate;

  ReceivePort? _receivePort;

  late final Future<SendPort> _workerSendPort;

  Completer<void>? _cleanCompleter;

  /// Completer for the worker send port initialization.
  /// Exposed for testing purposes only.
  @visibleForTesting
  Completer<SendPort>? sendPortCompleterForTesting;

  /// Getter for the clean completer.
  /// Exposed for testing purposes only.
  @visibleForTesting
  Completer<void>? get cleanCompleterForTesting => _cleanCompleter;

  /// Setter for the clean completer.
  /// Exposed for testing purposes only.
  @visibleForTesting
  set cleanCompleterForTesting(Completer<void>? value) {
    _cleanCompleter = value;
  }

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    (await _workerSendPort).send(record);
  }

  Future<SendPort> _startLogging() async {
    final ReceivePort port = ReceivePort();
    _receivePort = port;
    _isolate = await Isolate.spawn(
      _startWorker,
      port.sendPort,
      errorsAreFatal: false,
      debugName: '${logNamePrefix.toLowerCase()}_isolate_file_log_handler',
      onError: port.sendPort,
      onExit: port.sendPort,
    );

    final Completer<SendPort> sendPortCompleter = Completer<SendPort>();
    sendPortCompleterForTesting = sendPortCompleter;

    port.listen(
      (Object? message) => handlePortMessage(message, sendPortCompleter),
      onError: handlePortError,
      onDone: handlePortDone,
    );

    return sendPortCompleter.future;
  }

  /// Handles messages received from the isolate port.
  ///
  /// This method processes two types of messages:
  /// - [SendPort]: The worker's send port for communication
  /// - [cleanCompletedMessage]: Signal that cleanup is complete
  ///
  /// The method includes guards to prevent completing an already
  /// completed Completer, which can happen when Isolate.spawn sends
  /// multiple messages (e.g., error/exit messages) to the same port.
  ///
  /// This method is visible for testing to allow verification
  /// of the Completer guard behavior.
  @visibleForTesting
  void handlePortMessage(
    Object? message,
    Completer<SendPort> sendPortCompleter,
  ) {
    if (message is SendPort) {
      _handleSendPortMessage(message, sendPortCompleter);
    } else if (message == cleanCompletedMessage) {
      _handleCleanCompletedMessage();
    }
  }

  /// Handles the SendPort message from the worker isolate.
  ///
  /// Sends configuration options to the worker and completes
  /// the sendPortCompleter with the worker's port.
  void _handleSendPortMessage(
    SendPort workerPort,
    Completer<SendPort> sendPortCompleter,
  ) {
    workerPort.send(
      _FileLogHandlerOptions(
        logFileDirectory: logFileDirectory,
        maxFilesCount: maxFilesCount,
        logNamePrefix: logNamePrefix,
        maxLogSize: maxLogSizeInMb,
        supportedLevels:
            supportedLevels.map((BDLevel level) => level.importance).toList(),
      ),
    );
    // Guard against completing an already completed Completer.
    // This can happen when Isolate.spawn sends multiple messages
    // (e.g., error/exit messages) to the same port before or after
    // the SendPort message, especially during rapid background callbacks.
    if (!sendPortCompleter.isCompleted) {
      sendPortCompleter.complete(workerPort);
    }
  }

  /// Handles the clean completed message from the worker isolate.
  ///
  /// Kills the isolate and completes the clean completer.
  void _handleCleanCompletedMessage() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    // Guard against completing an already completed Completer.
    if (_cleanCompleter != null && !_cleanCompleter!.isCompleted) {
      _cleanCompleter?.complete();
    }
  }

  @override
  bool supportLevel(BDLevel level) => supportedLevels.contains(level);

  @override
  Future<void> clean() async {
    // Guard against calling clean() multiple times concurrently.
    // If a clean is already in progress, return the existing future.
    if (_cleanCompleter != null && !_cleanCompleter!.isCompleted) {
      return _cleanCompleter!.future;
    }
    _cleanCompleter = Completer<void>();
    (await _workerSendPort).send(_cleanCommand);
    return _cleanCompleter!.future;
  }

  /// Handles errors from the receive port stream.
  ///
  /// This method is called when an error occurs in the port's stream.
  /// It logs the error using the configured [_logFunction].
  ///
  /// This method is visible for testing to allow verification
  /// of error handling behavior.
  @visibleForTesting
  void handlePortError(Object exception, StackTrace stackTrace) {
    _logFunction(
      'IsolateFileLogHandler.onError',
      error: exception,
      stackTrace: stackTrace,
    );
  }

  /// Handles the completion of the receive port stream.
  ///
  /// This method is called when the port's stream is closed.
  /// It logs a message indicating the handler is done.
  ///
  /// This method is visible for testing to allow verification
  /// of stream completion handling.
  @visibleForTesting
  void handlePortDone() {
    _logFunction('IsolateFileLogHandler done');
  }
}

/// Top level function for isolate.
/// Receive port created first.
Future<void> _startWorker(Object message) async {
  _FileLoggerWorker(message as SendPort);
}

const String _cleanCommand = 'clean';

/// Message sent when cleanup is completed.
/// Exposed for testing purposes.
@visibleForTesting
const String cleanCompletedMessage = 'clean_completed';

class _FileLoggerWorker {
  _FileLoggerWorker(this._sendPort) {
    _receivePort = ReceivePort();
    _sendPort.send(_receivePort.sendPort);
    _receivePort.listen((Object? message) async {
      if (message is _FileLogHandlerOptions) {
        _initialise(message);
        _processPendingRecords();
      } else if (message is BDLogRecord) {
        if (_isInitialized) {
          await _processRequest(message);
        } else {
          _pendingRecords.add(message);
        }
      } else if (message == _cleanCommand) {
        if (_isInitialized) {
          await _fileLogHandler.clean();
        }
        _sendPort.send(cleanCompletedMessage);
        _receivePort.close();
      }
    });
  }

  final SendPort _sendPort;
  late final ReceivePort _receivePort;
  late final FileLogHandler _fileLogHandler;
  bool _isInitialized = false;
  final List<BDLogRecord> _pendingRecords = <BDLogRecord>[];

  void _initialise(_FileLogHandlerOptions options) {
    _fileLogHandler = FileLogHandler(
      logNamePrefix: options.logNamePrefix,
      maxLogSizeInMb: options.maxLogSize,
      maxFilesCount: options.maxFilesCount,
      logFileDirectory: options.logFileDirectory,
      supportedLevels: _mapLevels(options.supportedLevels),
    );
    _isInitialized = true;
  }

  Future<void> _processPendingRecords() async {
    for (final BDLogRecord record in _pendingRecords) {
      await _processRequest(record);
    }
    _pendingRecords.clear();
  }

  Future<void> _processRequest(BDLogRecord record) async {
    await _fileLogHandler.handleRecord(record);
  }

  static List<BDLevel> _mapLevels(List<int> supportedLevels) {
    final Set<BDLevel> levels = <BDLevel>{};

    for (final int importance in supportedLevels) {
      for (final BDLevel level in BDLevel.values) {
        if (level.importance == importance) {
          levels.add(level);
          break;
        }
      }
    }

    return levels.toList();
  }
}

class _FileLogHandlerOptions {
  final Directory logFileDirectory;
  final int maxFilesCount;
  final String logNamePrefix;
  final int maxLogSize;
  final List<int> supportedLevels;

  _FileLogHandlerOptions({
    required this.maxLogSize,
    required this.maxFilesCount,
    required this.logNamePrefix,
    required this.supportedLevels,
    required this.logFileDirectory,
  });
}
