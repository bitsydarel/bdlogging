import 'dart:async';
import 'dart:io';

import 'package:bdlogging/bdlogging.dart';

/// [BDLogFormatter] that defines how a [BDLogRecord] is formatted.
class FormattedIsolateFileLogHandler extends IsolateFileLogHandler {
  /// [BDLogFormatter] that define how [BDLogRecord].
  final BDLogFormatter logFormatter;

  /// Constructs a [FormattedIsolateFileLogHandler]
  /// with an optional [logFormatter].
  ///
  /// The [logFormatter] defines how [BDLogRecord]s are formatted
  /// before being handled.
  /// Defaults to [DefaultLogFormatter] if not provided.
  FormattedIsolateFileLogHandler(
      Directory logFileDirectory, {
        int maxFilesCount = 5,
        String logNamePrefix = '_log',
        int maxLogSizeInMb = 5,
        List<BDLevel> supportedLevels = const <BDLevel>[
          BDLevel.warning,
          BDLevel.success,
          BDLevel.error,
        ],
        this.logFormatter = const DefaultLogFormatter(),
      }) : super(
    logFileDirectory,
    maxFilesCount: maxFilesCount,
    logNamePrefix: logNamePrefix,
    maxLogSizeInMb: maxLogSizeInMb,
    supportedLevels: supportedLevels,
  );

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    final String formattedMessage = logFormatter.format(record);
    final BDLogRecord formattedRecord = BDLogRecord(
      record.level,
      formattedMessage,
      error: record.error,
      stackTrace: record.stackTrace,
      isFatal: record.isFatal,
    );
    await super.handleRecord(formattedRecord);
  }
}
