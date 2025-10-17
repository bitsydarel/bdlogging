import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:bdlogging/bdlogging.dart';
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
    this.logFormatter = const DefaultLogFormatter(),
  })  : assert(
          logNamePrefix.isNotEmpty,
          'logNamePrefix should not be empty',
        ),
        assert(
          maxLogSizeInMb > 0,
          'maxLogSizeInMb should not be lower than zero',
        ) {
    _workerSendPort = _startLogging(logFormatter);
  }

  /// [BDLogFormatter] that define how [BDLogRecord].
  final BDLogFormatter logFormatter;

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

  late final Future<SendPort> _workerSendPort;

  Completer<void>? _cleanCompleter;

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    (await _workerSendPort).send(record);
  }

  Future<SendPort> _startLogging(BDLogFormatter logFormatter) async {
    final ReceivePort port = ReceivePort();
    _isolate = await Isolate.spawn(
      _startWorker,
      <Object>[port.sendPort, logFormatter],
      errorsAreFatal: false,
      debugName: '${logNamePrefix.toLowerCase()}_isolate_file_log_handler',
      onError: port.sendPort,
      onExit: port.sendPort,
    );

    final Completer<SendPort> sendPortCompleter = Completer<SendPort>();

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
          sendPortCompleter.complete(workerPort);
        } else if (message == _cleanCompletedMessage) {
          _isolate?.kill(priority: Isolate.immediate);
          _cleanCompleter?.complete();
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
    return _cleanCompleter!.future;
  }
}

/// Top level function for isolate.
/// Receive port created first.
Future<void> _startWorker(List<dynamic> args) async {
  final SendPort sendPort = args[0] as SendPort;
  final BDLogFormatter logFormatter = args[1] as BDLogFormatter;
  _FileLoggerWorker(sendPort, logFormatter);
}

const String _cleanCommand = 'clean';
const String _cleanCompletedMessage = 'clean_completed';

class _FileLoggerWorker {
  _FileLoggerWorker(this._sendPort, this._logFormatter) {
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

  final BDLogFormatter _logFormatter;

  final SendPort _sendPort;
  late final ReceivePort _receivePort;
  late final FileLogHandler _fileLogHandler;

  void _initialise(_FileLogHandlerOptions options) {
    _fileLogHandler = FileLogHandler(
      logNamePrefix: options.logNamePrefix,
      maxLogSizeInMb: options.maxLogSize,
      maxFilesCount: options.maxFilesCount,
      logFileDirectory: options.logFileDirectory,
      logFormatter: _logFormatter,
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
