import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer';

import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_formatter.dart';
import 'package:bdlogging/src/bd_log_handler.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:bdlogging/src/formatters/default_log_formatter.dart';
import 'package:flutter/foundation.dart';
import 'package:io/ansi.dart' as ansi;

const LineSplitter _lineSplitter = LineSplitter();

/// A Function that reschedule a [callback] function after the specified
/// [duration] elapse.
typedef RescheduleCallback = void Function(
  Duration duration,
  void Function() callback,
);

/// A implementation of [BDLogHandler] that print [BDLogRecord] to the console.
class ConsoleLogHandler extends BDLogHandler {
  /// Maximum characters length in byte that can be printed before
  /// [maxPrintPause] is required.
  static const int maxPrintCapacity = 12 * 1024;

  /// Maximum pause time required before restarting to print logs.
  static const Duration maxPrintPause = Duration(seconds: 1);

  final Queue<String> _logsBuffer;

  final Stopwatch _printPauseWatcher;

  /// [BDLogFormatter] that define how [BDLogRecord] should printed on console.
  final BDLogFormatter logFormatter;

  /// Minimum supported [BDLevel] for [BDLogRecord].
  final BDLevel minimumSupportedLevel;

  /// [RescheduleCallback] that's called to reschedule log printing.
  final RescheduleCallback _reschedulePrinting;

  /// Create a new instance of the [ConsoleLogHandler].
  ///
  /// Or reuse a already available instance.
  factory ConsoleLogHandler({
    BDLogFormatter logFormatter = const DefaultLogFormatter(),
    BDLevel minimumSupportedLevel = BDLevel.debug,
  }) {
    return ConsoleLogHandler.private(
      minimumSupportedLevel,
      logFormatter,
      Queue<String>(),
      Stopwatch()
        ..reset()
        ..start(),
      (Duration duration, void Function() callback) {
        Timer(duration, callback);
      },
    );
  }

  /// Private constructor mostly for testing purpose.
  @visibleForTesting
  const ConsoleLogHandler.private(
    this.minimumSupportedLevel,
    this.logFormatter,
    this._logsBuffer,
    this._printPauseWatcher,
    this._reschedulePrinting,
  );

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    final String rawLines = logFormatter.format(record);

    final List<String> lines = _lineSplitter.convert(rawLines);

    _logsBuffer.addAll(lines);

    throttleLogPrint();
  }

  @override
  bool supportLevel(BDLevel level) => level >= minimumSupportedLevel;

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
        // ignore: avoid_print
        log(colorLine(line));
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
