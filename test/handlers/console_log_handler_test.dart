import 'dart:collection';

import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:bdlogging/src/formatters/default_log_formatter.dart';
import 'package:bdlogging/src/handlers/console_log_handler.dart';
import 'package:io/ansi.dart' as ansi;
import 'package:mocktail/mocktail.dart' as mockito;
import 'package:test/test.dart';

const String ansiMarkerEnd = '[0m';

String getAnsiMarkerStart(final int ansiColorCode) {
  return '[${ansiColorCode}m';
}

const Duration friction = Duration(milliseconds: 100);

void main() {
  test(
    'should only log event with BDLevel equal or greater than'
    ' minimumSupportedBDLevel',
    () {
      final ConsoleLogHandler handler = ConsoleLogHandler(
        supportedLevels: <BDLevel>[BDLevel.error],
      );

      expect(handler.supportLevel(BDLevel.info), isFalse);
      expect(handler.supportLevel(BDLevel.warning), isFalse);
      expect(handler.supportLevel(BDLevel.error), isTrue);
    },
  );

  group(
    'colorLine',
    () {
      final ConsoleLogHandler handler = ConsoleLogHandler();

      test('should color line with blue color for DEBUG log BDLevel', () {
        const String log = '2021-06-09 14:40:24.863623 DEBUG: '
            'Days until death 10 at logged 2021-06-09 14:40:24.859826';

        final String ansiMarkerStart = getAnsiMarkerStart(ansi.blue.code);

        ansi.overrideAnsiOutput<void>(true, () {
          final String coloredLog = handler.colorLine(log);

          expect(coloredLog, startsWith(ansiMarkerStart));
          expect(coloredLog, endsWith(ansiMarkerEnd));
        });
      });

      test('should color line with blue color for WARNING log BDLevel', () {
        const String log = '2021-06-09 14:40:24.863623 WARNING: '
            'Days until death 10 at logged 2021-06-09 14:40:24.859826';

        final String ansiMarkerStart = getAnsiMarkerStart(ansi.yellow.code);

        ansi.overrideAnsiOutput<void>(true, () {
          final String coloredLog = handler.colorLine(log);

          expect(coloredLog, startsWith(ansiMarkerStart));
          expect(coloredLog, endsWith(ansiMarkerEnd));
        });
      });

      test('should color line with blue color for ERROR log BDLevel', () {
        const String log = '2021-06-09 14:40:24.863623 ERROR: '
            'Days until death 10 at logged 2021-06-09 14:40:24.859826';

        final String ansiMarkerStart = getAnsiMarkerStart(ansi.red.code);

        ansi.overrideAnsiOutput<void>(true, () {
          final String coloredLog = handler.colorLine(log);

          expect(coloredLog, startsWith(ansiMarkerStart));
          expect(coloredLog, endsWith(ansiMarkerEnd));
        });
      });

      test('should color line with blue color for INFO log BDLevel', () {
        const String log = '2021-06-09 14:40:24.863623 INFO: '
            'Days until death 10 at logged 2021-06-09 14:40:24.859826';

        final String ansiMarkerStart = getAnsiMarkerStart(ansi.white.code);

        ansi.overrideAnsiOutput<void>(true, () {
          final String coloredLog = handler.colorLine(log);

          expect(coloredLog, startsWith(ansiMarkerStart));
          expect(coloredLog, endsWith(ansiMarkerEnd));
        });
      });
    },
  );

  group(
    'throttleLogPrint',
    () {
      test(
        'should print only if print pause watcher has exceeded maxPrintPause',
        () {
          final Queue<String> logBuffer = Queue<String>()
            ..add(
              '2021-06-09 14:40:24.863623 DEBUG: '
              'Days until death 10 at logged 2021-06-09 14:40:24.859826',
            );

          final _MockPauseWatcher printPauseWatcher = _MockPauseWatcher();

          final ConsoleLogHandler handler = ConsoleLogHandler.private(
            <BDLevel>[BDLevel.info],
            const DefaultLogFormatter(),
            logBuffer,
            printPauseWatcher,
            (Duration _, void Function() __) {},
            print,
          );

          mockito
              .when(() => printPauseWatcher.elapsed)
              .thenReturn(ConsoleLogHandler.maxPrintPause + friction);

          handler.throttleLogPrint();

          expect(logBuffer, isEmpty);
        },
      );

      test(
        'should not print more than allowed by maxPrintCapacity',
        () {
          final Queue<String> logBuffer = Queue<String>();

          const String log = '2021-06-09 14:40:24.863623 DEBUG: '
              'Days until death 10 at logged 2021-06-09 14:40:24.859826';

          while (logBuffer.length <= ConsoleLogHandler.maxPrintCapacity) {
            logBuffer.add(log);
          }

          expect(
            logBuffer.length,
            greaterThan(ConsoleLogHandler.maxPrintCapacity),
          );

          final _MockPauseWatcher printPauseWatcher = _MockPauseWatcher();

          final ConsoleLogHandler handler = ConsoleLogHandler.private(
            <BDLevel>[BDLevel.info],
            const DefaultLogFormatter(),
            logBuffer,
            printPauseWatcher,
            (Duration _, void Function() __) {},
            print,
          );

          mockito
              .when(() => printPauseWatcher.elapsed)
              .thenReturn(ConsoleLogHandler.maxPrintPause + friction);

          handler.throttleLogPrint();

          expect(logBuffer, isNotEmpty);
          expect(
            logBuffer.length,
            lessThan(ConsoleLogHandler.maxPrintCapacity),
          );
        },
      );

      test(
        'should be rescheduled if after log printing, log buffer is not empty',
        () {
          final Queue<String> logBuffer = Queue<String>();

          const String log = '2021-06-09 14:40:24.863623 DEBUG: '
              'Days until death 10 at logged 2021-06-09 14:40:24.859826';

          while (logBuffer.length <= ConsoleLogHandler.maxPrintCapacity) {
            logBuffer.add(log);
          }

          expect(
            logBuffer.length,
            greaterThan(ConsoleLogHandler.maxPrintCapacity),
          );

          final _MockPauseWatcher printPauseWatcher = _MockPauseWatcher();
          final _MockRescheduleCallback rescheduleCallback =
              _MockRescheduleCallback();

          final ConsoleLogHandler handler = ConsoleLogHandler.private(
            <BDLevel>[BDLevel.info],
            const DefaultLogFormatter(),
            logBuffer,
            printPauseWatcher,
            rescheduleCallback,
            print,
          );

          mockito
              .when(() => printPauseWatcher.elapsed)
              .thenReturn(ConsoleLogHandler.maxPrintPause + friction);

          handler.throttleLogPrint();

          expect(logBuffer, isNotEmpty);
          expect(
              logBuffer.length, lessThan(ConsoleLogHandler.maxPrintCapacity));

          mockito
              .verify(
                () => rescheduleCallback.call(
                  ConsoleLogHandler.maxPrintPause,
                  mockito.any(),
                ),
              )
              .called(1);

          mockito.verifyNoMoreInteractions(rescheduleCallback);
        },
      );

      test(
        'should reschedule printing to the remaining duration if '
        'elapsed print pause is not greater than maxPrintPause',
        () {
          final _MockPauseWatcher printPauseWatcher = _MockPauseWatcher();
          final _MockRescheduleCallback rescheduleCallback =
              _MockRescheduleCallback();

          final ConsoleLogHandler handler = ConsoleLogHandler.private(
            <BDLevel>[BDLevel.info],
            const DefaultLogFormatter(),
            Queue<String>(),
            printPauseWatcher,
            rescheduleCallback,
            print,
          );

          mockito
              .when(() => printPauseWatcher.elapsed)
              .thenReturn(ConsoleLogHandler.maxPrintPause - friction);

          handler.throttleLogPrint();

          mockito
              .verify(
                () => rescheduleCallback.call(friction, mockito.any()),
              )
              .called(1);

          mockito.verifyNoMoreInteractions(rescheduleCallback);
        },
      );

      test(
        'should stop and reset printPauseWatcher when printing is starting',
        () {
          final _MockPauseWatcher printPauseWatcher = _MockPauseWatcher();

          final ConsoleLogHandler handler = ConsoleLogHandler.private(
            <BDLevel>[BDLevel.info],
            const DefaultLogFormatter(),
            Queue<String>(),
            printPauseWatcher,
            (Duration duration, void Function() _) {},
            print,
          );

          mockito
              .when(() => printPauseWatcher.elapsed)
              .thenReturn(ConsoleLogHandler.maxPrintPause + friction);

          handler.throttleLogPrint();

          mockito.verifyInOrder<void>(
            <void Function()>[
              printPauseWatcher.stop,
              printPauseWatcher.reset,
            ],
          );
        },
      );

      test(
        'should start printPauseWatcher when printing is done',
        () {
          final _MockPauseWatcher printPauseWatcher = _MockPauseWatcher();

          final Queue<String> logBuffer = Queue<String>()
            ..add(
              '2021-06-09 14:40:24.863623 DEBUG: '
              'Days until death 10 at logged 2021-06-09 14:40:24.859826',
            );

          final ConsoleLogHandler handler = ConsoleLogHandler.private(
            <BDLevel>[BDLevel.info],
            const DefaultLogFormatter(),
            logBuffer,
            printPauseWatcher,
            (Duration duration, void Function() _) {},
            print,
          );

          mockito
              .when(() => printPauseWatcher.elapsed)
              .thenReturn(ConsoleLogHandler.maxPrintPause + friction);

          expect(logBuffer, isNotEmpty);

          handler.throttleLogPrint();

          expect(logBuffer, isEmpty);

          mockito.verify(printPauseWatcher.start).called(1);
        },
      );
    },
  );

  group('handleRecord', () {
    final BDLogRecord record = BDLogRecord(
        BDLevel.debug,
        '2021-06-09 14:40:24 DEBUG: '
        'Days until death 10 at logged 2021-06-09 14:40:24');

    test('should format log with formatter', () {
      final DefaultLogFormatter formatter = _MockFormatter();
      final Queue<String> logBuffer = Queue<String>();
      final _MockPauseWatcher printPauseWatcher = _MockPauseWatcher();

      final ConsoleLogHandler handler = ConsoleLogHandler.private(
        <BDLevel>[BDLevel.info],
        formatter,
        logBuffer,
        printPauseWatcher,
        (Duration duration, void Function() _) {},
        print,
      );

      mockito.when(() => formatter.format(record)).thenReturn(record.message);

      mockito
          .when(() => printPauseWatcher.elapsed)
          .thenReturn(ConsoleLogHandler.maxPrintPause + friction);

      handler.handleRecord(record);

      mockito.verify(() => formatter.format(record)).called(1);
    });

    test(
        'should remove last log from logBuffer by calling '
        'throttleLogPrint', () async {
      final Queue<String> _logBuffer = Queue<String>();
      final ConsoleLogHandler handler = ConsoleLogHandler.private(
        <BDLevel>[BDLevel.info],
        const DefaultLogFormatter(),
        _logBuffer,
        Stopwatch(),
        (Duration duration, void Function() _) {},
        print,
      );

      await handler.handleRecord(BDLogRecord(BDLevel.debug, 'abc'));

      expect(_logBuffer.last, isNot(equals('abc')));
    });
  });
}

class _MockRescheduleCallback extends mockito.Mock {
  void call(Duration duration, void Function() callback);
}

class _MockPauseWatcher extends mockito.Mock implements Stopwatch {}

class _MockFormatter extends mockito.Mock implements DefaultLogFormatter {}
