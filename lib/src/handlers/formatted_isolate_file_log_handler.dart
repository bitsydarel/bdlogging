import 'dart:async';

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
    super.logFileDirectory, {
    this.logFormatter = const DefaultLogFormatter(),
  });

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    final String rawLines = logFormatter.format(record);

    final BDLogRecord formattedRecord = BDLogRecord(
      record.level,
      rawLines,
      error: record.error,
      stackTrace: record.stackTrace,
      isFatal: record.isFatal,
    );

    super.handleRecord(formattedRecord);
  }
}
