import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_formatter.dart';
import 'package:bdlogging/src/bd_log_handler.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:bdlogging/src/formatters/default_log_formatter.dart';
import 'package:io/ansi.dart' as ansi;
import 'package:meta/meta.dart';

const LineSplitter _lineSplitter = LineSplitter();

/// A Function that reschedule a [callback] function after the specified
/// [duration] elapse.
typedef RescheduleCallback = void Function(
  Duration duration,
  void Function() callback,
);

/// A [Function] that print the line.
typedef LinePrinter = void Function(String line);

/// A implementation of [BDLogHandler] that print [BDLogRecord] to the console.
class ConsoleLogHandler extends BDLogHandler {
  /// Create a new instance of the [ConsoleLogHandler].
  ///
  /// Or reuse a already available instance.
  factory ConsoleLogHandler({
    BDLogFormatter logFormatter = const DefaultLogFormatter(),
    List<BDLevel> supportedLevels = const <BDLevel>[BDLevel.debug],
    LinePrinter? printer,
  }) {
    return ConsoleLogHandler.private(
      supportedLevels,
      logFormatter,
      Queue<String>(),
      Stopwatch()
        ..reset()
        ..start(),
      (Duration duration, void Function() callback) {
        Timer(duration, callback);
      },
      printer ?? print,
    );
  }

  /// Private constructor mostly for testing purpose.
  @visibleForTesting
  const ConsoleLogHandler.private(
    this.supportedLevels,
    this.logFormatter,
    this._logsBuffer,
    this._printPauseWatcher,
    this._reschedulePrinting,
    this._printer,
  );

  /// Maximum characters length in byte that can be printed before
  /// [maxPrintPause] is required.
  static const int maxPrintCapacity = 12 * 1024;

  /// Maximum pause time required before restarting to print logs.
  static const Duration maxPrintPause = Duration(seconds: 1);

  final Queue<String> _logsBuffer;

  final Stopwatch _printPauseWatcher;

  /// [BDLogFormatter] that define how [BDLogRecord] should printed on console.
  final BDLogFormatter logFormatter;

  /// Supported [BDLevel] of [BDLogRecord].
  final List<BDLevel> supportedLevels;

  /// [RescheduleCallback] that's called to reschedule log printing.
  final RescheduleCallback _reschedulePrinting;

  /// Function that's called to print a line to the console.
  final LinePrinter _printer;

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    final String rawLines = logFormatter.format(record);

    final List<String> lines = _lineSplitter.convert(rawLines);

    _logsBuffer.addAll(lines);

    throttleLogPrint();
  }

  @override
  bool supportLevel(BDLevel level) => supportedLevels.contains(level);

  /// Implementation of print that throttles messages.
  /// This avoids dropping messages on platforms that rate-limit their logging.
  @visibleForTesting
  void throttleLogPrint() {
    // check if pause time is passed, if yes we reset our timer
    // and start print those logs to the console.
    if (_printPauseWatcher.elapsed > maxPrintPause) {
      _printPauseWatcher
        ..stop()
        ..reset();

      int printedCharacters = 0;

      while (printedCharacters < maxPrintCapacity && _logsBuffer.isNotEmpty) {
        final String line = _logsBuffer.removeFirst();

        // TODO(bitsydarel): Use the UTF-8 byte length instead
        printedCharacters += line.length;
        // because we want to print to the default console in any
        // run environment.
        _printer(colorLine(line));
      }

      // we start watcher again after to printing, so we can be sure that we
      // waited maxPrintPause before trying to reprint.
      _printPauseWatcher.start();

      // check if the buffer is not empty yet but we already exceed our
      // print capacity, so we need to schedule another run of this method.
      if (_logsBuffer.isNotEmpty) {
        _reschedulePrinting(maxPrintPause, throttleLogPrint);
      }
    } else {
      _reschedulePrinting(
        maxPrintPause - _printPauseWatcher.elapsed,
        throttleLogPrint,
      );
    }
  }

  /// Colors line depending on [BDLevel].
  @visibleForTesting
  String colorLine(String line) {
    if (line.contains(BDLevel.debug.name)) {
      return ansi.blue.wrap(line) ?? line;
    } else if (line.contains(BDLevel.warning.name)) {
      return ansi.yellow.wrap(line) ?? line;
    } else if (line.contains(BDLevel.error.name)) {
      return ansi.red.wrap(line) ?? line;
    } else {
      return ansi.white.wrap(line) ?? line;
    }
  }
}
