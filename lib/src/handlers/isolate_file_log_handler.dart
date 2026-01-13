import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:bdlogging/src/bd_cleanable_log_handler.dart';
import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:bdlogging/src/handlers/file_log_handler.dart';

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
  })  : assert(
          logNamePrefix.isNotEmpty,
          'logNamePrefix should not be empty',
        ),
        assert(
          maxLogSizeInMb > 0,
          'maxLogSizeInMb should not be lower than zero',
        ) {
    _workerSendPort = _startLogging();
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

  Isolate? _isolate;

  /// Separate port for receiving error and exit messages from the worker isolate.
  /// This prevents interference with the main communication port.
  ReceivePort? _errorPort;

  late final Future<SendPort> _workerSendPort;

  Completer<void>? _cleanCompleter;

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    (await _workerSendPort).send(record);
  }

  Future<SendPort> _startLogging() async {
    final ReceivePort port = ReceivePort();
    
    // Create a separate port for error and exit messages to prevent
    // interference with the main communication port and avoid race conditions
    // when the handler is rapidly destroyed and recreated.
    final ReceivePort errorPort = ReceivePort();
    _errorPort = errorPort;
    
    _isolate = await Isolate.spawn(
      _startWorker,
      port.sendPort,
      errorsAreFatal: false,
      debugName: '${logNamePrefix.toLowerCase()}_isolate_file_log_handler',
      onError: errorPort.sendPort,
      onExit: errorPort.sendPort,
    );

    final Completer<SendPort> sendPortCompleter = Completer<SendPort>();
    
    // Listen to error/exit messages on a separate port
    errorPort.listen(
      (Object? message) {
        // Log any errors or exit notifications from the worker isolate
        // but don't interact with the sendPortCompleter to avoid race conditions
        if (message is List && message.length >= 2) {
          // Error message format: [errorString, stackTraceString]
          log(
            'IsolateFileLogHandler worker error',
            error: message[0],
            stackTrace: message[1] != null 
                ? StackTrace.fromString(message[1].toString()) 
                : null,
          );
        } else if (message == null) {
          // Exit notification (null is sent when isolate exits)
          log('IsolateFileLogHandler worker isolate exited');
        }
      },
      onError: (Object exception, StackTrace stackTrace) {
        log(
          'IsolateFileLogHandler.errorPort.onError',
          error: exception,
          stackTrace: stackTrace,
        );
      },
    );

    port.listen(
      (Object? message) {
        if (message is SendPort) {
          final SendPort workerPort = message
            ..send(
              _FileLogHandlerOptions(
                logFileDirectory: logFileDirectory,
                maxFilesCount: maxFilesCount,
                logNamePrefix: logNamePrefix,
                maxLogSize: maxLogSizeInMb,
                supportedLevels: supportedLevels
                    .map((BDLevel level) => level.importance)
                    .toList(),
              ),
            );
          // Guard against completing an already completed completer
          // This can happen in race conditions when the handler is
          // rapidly destroyed and recreated
          if (!sendPortCompleter.isCompleted) {
            sendPortCompleter.complete(workerPort);
          }
        } else if (message == _cleanCompletedMessage) {
          _isolate?.kill(priority: Isolate.immediate);
          // Guard against completing an already completed completer
          if (!(_cleanCompleter?.isCompleted ?? true)) {
            _cleanCompleter?.complete();
          }
        }
      },
      onError: (Object exception, StackTrace stackTrace) {
        log(
          'IsolateFileLogHandler.onError',
          error: exception,
          stackTrace: stackTrace,
        );
      },
      onDone: () => log('IsolateFileLogHandler done'),
    );

    return sendPortCompleter.future;
  }

  @override
  bool supportLevel(BDLevel level) => supportedLevels.contains(level);

  @override
  Future<void> clean() async {
    (await _workerSendPort).send(_cleanCommand);
    _cleanCompleter = Completer<void>();
    
    // Close the error port to clean up resources
    _errorPort?.close();
    _errorPort = null;
    
    return _cleanCompleter!.future;
  }
}

/// Top level function for isolate.
/// Receive port created first.
Future<void> _startWorker(Object message) async {
  _FileLoggerWorker(message as SendPort);
}

const String _cleanCommand = 'clean';
const String _cleanCompletedMessage = 'clean_completed';

class _FileLoggerWorker {
  _FileLoggerWorker(this._sendPort) {
    _receivePort = ReceivePort();
    _sendPort.send(_receivePort.sendPort);
    _receivePort.listen((Object? message) async {
      if (message is _FileLogHandlerOptions) {
        _initialise(message);
      } else if (message is BDLogRecord) {
        _processRequest(message);
      } else if (message == _cleanCommand) {
        await _fileLogHandler.clean();
        _sendPort.send(_cleanCompletedMessage);
      }
    });
  }

  final SendPort _sendPort;
  late final ReceivePort _receivePort;
  late final FileLogHandler _fileLogHandler;

  void _initialise(_FileLogHandlerOptions options) {
    _fileLogHandler = FileLogHandler(
      logNamePrefix: options.logNamePrefix,
      maxLogSizeInMb: options.maxLogSize,
      maxFilesCount: options.maxFilesCount,
      logFileDirectory: options.logFileDirectory,
      supportedLevels: _mapLevels(options.supportedLevels),
    );
  }

  void _processRequest(BDLogRecord record) {
    _fileLogHandler.handleRecord(record);
  }

  static List<BDLevel> _mapLevels(List<int> supportedLevels) {
    final Set<BDLevel> levels = <BDLevel>{};

    supportedLevels.forEach((int level) {
      switch (level) {
        case 3:
          levels.add(BDLevel.debug);
          break;
        case 4:
          levels.add(BDLevel.info);
          break;
        case 5:
          levels.add(BDLevel.warning);
          break;
        case 6:
          levels.add(BDLevel.error);
          break;
      }
    });

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
