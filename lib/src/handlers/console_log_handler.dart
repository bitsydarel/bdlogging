import 'dart:async';
import 'dart:convert';

import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_formatter.dart';
import 'package:bdlogging/src/bd_log_handler.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:bdlogging/src/formatters/default_log_formatter.dart';
import 'package:io/ansi.dart' as ansi;
import 'package:meta/meta.dart';

const LineSplitter _lineSplitter = LineSplitter();

/// A [Function] that print the line.
typedef LinePrinter = void Function(String line);

/// A implementation of [BDLogHandler] that print [BDLogRecord] to the console.
/// This class is responsible for handling log records
/// and printing them to the console.
///
/// It supports different log levels and
/// can format the log records before printing.
class ConsoleLogHandler extends BDLogHandler {
  /// Create a new instance of the [ConsoleLogHandler].
  ///
  /// Or reuse a already available instance.
  /// [printer] is a function that's called to print a line to the console.
  /// [supportedLevels] are the log levels that this handler supports.
  /// [logFormatter] is the formatter that defines how log records
  /// should be printed on console.
  factory ConsoleLogHandler({
    LinePrinter? printer,
    List<BDLevel> supportedLevels = BDLevel.values,
    BDLogFormatter logFormatter = const DefaultLogFormatter(),
  }) {
    return ConsoleLogHandler.private(
      supportedLevels,
      logFormatter,
      printer ?? Zone.current.print,
    );
  }

  /// Private constructor mostly for testing purpose.
  ///
  /// This constructor is used to create a new instance of
  /// the ConsoleLogHandler with specific parameters.
  ///
  /// It's marked as visible for testing, so it can be used in tests
  /// to create instances with specific parameters.
  @visibleForTesting
  const ConsoleLogHandler.private(
    this.supportedLevels,
    this.logFormatter,
    this._printer,
  );

  /// Function that's called to print a line to the console.
  final LinePrinter _printer;

  /// [BDLogFormatter] that define how [BDLogRecord] should printed on console.
  final BDLogFormatter logFormatter;

  /// Supported [BDLevel] of [BDLogRecord].
  final List<BDLevel> supportedLevels;

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    final String rawLines = logFormatter.format(record);

    _lineSplitter
        .convert(rawLines)
        .forEach((String line) => _printer(colorLine(record.level, line)));
  }

  @override
  bool supportLevel(BDLevel level) => supportedLevels.contains(level);

  /// This method colors a line depending on its log level.
  ///
  /// It checks if the line contains the label of
  /// a log level and colors it accordingly.
  @visibleForTesting
  String colorLine(BDLevel level, String line) {
    switch (level) {
      case BDLevel.debug:
        return ansi.blue.wrap(line) ?? line;
      case BDLevel.info:
        return ansi.white.wrap(line) ?? line;
      case BDLevel.warning:
        return ansi.yellow.wrap(line) ?? line;
      case BDLevel.success:
        return ansi.green.wrap(line) ?? line;
      case BDLevel.error:
        return ansi.red.wrap(line) ?? line;
    }
  }
}
