import 'dart:async';

import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:bdlogging/src/formatters/default_log_formatter.dart';
import 'package:bdlogging/src/handlers/console_log_handler.dart';
import 'package:io/ansi.dart' as ansi;
import 'package:mocktail/mocktail.dart' as mockito;
import 'package:test/test.dart';

const String ansiMarkerEnd = '\x1B[0m';

String getAnsiMarkerStart(final int ansiColorCode) {
  return '\x1B[${ansiColorCode}m';
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
          final String coloredLog = handler.colorLine(BDLevel.debug, log);

          expect(coloredLog, startsWith(ansiMarkerStart));
          expect(coloredLog, endsWith(ansiMarkerEnd));
          Zone.current.print(coloredLog);
        });
      });

      test('should color line with blue color for WARNING log BDLevel', () {
        const String log = '2021-06-09 14:40:24.863623 WARNING: '
            'Days until death 10 at logged 2021-06-09 14:40:24.859826';

        final String ansiMarkerStart = getAnsiMarkerStart(ansi.yellow.code);

        ansi.overrideAnsiOutput<void>(true, () {
          final String coloredLog = handler.colorLine(BDLevel.warning, log);

          expect(coloredLog, startsWith(ansiMarkerStart));
          expect(coloredLog, endsWith(ansiMarkerEnd));
          Zone.current.print(coloredLog);
        });
      });

      test('should color line with blue color for ERROR log BDLevel', () {
        const String log = '2021-06-09 14:40:24.863623 ERROR: '
            'Days until death 10 at logged 2021-06-09 14:40:24.859826';

        final String ansiMarkerStart = getAnsiMarkerStart(ansi.red.code);

        ansi.overrideAnsiOutput<void>(true, () {
          final String coloredLog = handler.colorLine(BDLevel.error, log);

          expect(coloredLog, startsWith(ansiMarkerStart));
          expect(coloredLog, endsWith(ansiMarkerEnd));
          Zone.current.print(coloredLog);
        });
      });

      test('should color line with blue color for INFO log BDLevel', () {
        const String log = '2021-06-09 14:40:24.863623 INFO: '
            'Days until death 10 at logged 2021-06-09 14:40:24.859826';

        final String ansiMarkerStart = getAnsiMarkerStart(ansi.white.code);

        ansi.overrideAnsiOutput<void>(true, () {
          final String coloredLog = handler.colorLine(BDLevel.info, log);

          expect(coloredLog, startsWith(ansiMarkerStart));
          expect(coloredLog, endsWith(ansiMarkerEnd));
          Zone.current.print(coloredLog);
        });
      });

      test('should color line with green color for SUCCESS log BDLevel', () {
        const String log = '2021-06-09 14:40:24.863623 SUCCESS: '
            'Days until death 10 at logged 2021-06-09 14:40:24.859826';

        final String ansiMarkerStart = getAnsiMarkerStart(ansi.green.code);

        ansi.overrideAnsiOutput<void>(true, () {
          final String coloredLog = handler.colorLine(BDLevel.success, log);

          expect(coloredLog, startsWith(ansiMarkerStart));
          expect(coloredLog, endsWith(ansiMarkerEnd));
          Zone.current.print(coloredLog);
        });
      });
    },
  );

  group('handleRecord', () {
    final BDLogRecord record = BDLogRecord(
        BDLevel.debug,
        '2021-06-09 14:40:24 DEBUG: '
        'Days until death 10 at logged 2021-06-09 14:40:24');

    test('should format log with formatter', () {
      final DefaultLogFormatter formatter = _MockFormatter();
      final List<String> receivedLines = <String>[];

      final ConsoleLogHandler handler = ConsoleLogHandler.private(
        <BDLevel>[BDLevel.info],
        formatter,
        (String line) {
          receivedLines.add(line);
          Zone.current.print(line);
        },
      );

      mockito.when(() => formatter.format(record)).thenReturn(record.message);

      handler.handleRecord(record);

      mockito.verify(() => formatter.format(record)).called(1);
    });
  });

  group('handleRecord edge cases', () {
    test('should handle multi-line log messages', () {
      final List<String> printedLines = <String>[];

      final ConsoleLogHandler handler = ConsoleLogHandler.private(
        BDLevel.values,
        const DefaultLogFormatter(),
        printedLines.add,
      );

      final BDLogRecord multiLineRecord = BDLogRecord(
        BDLevel.info,
        'Line 1\nLine 2\nLine 3',
      );

      handler.handleRecord(multiLineRecord);

      // Each line should be printed separately and colored
      expect(printedLines.length, greaterThanOrEqualTo(3));
    });

    test('should handle empty message', () {
      final List<String> printedLines = <String>[];

      final ConsoleLogHandler handler = ConsoleLogHandler.private(
        BDLevel.values,
        const DefaultLogFormatter(),
        printedLines.add,
      );

      final BDLogRecord emptyRecord = BDLogRecord(
        BDLevel.debug,
        '',
      );

      // Should not throw
      expect(
        () => handler.handleRecord(emptyRecord),
        returnsNormally,
      );
    });

    test('should call printer for each line of multi-line message', () {
      int callCount = 0;

      final _MockFormatter formatter = _MockFormatter();
      final ConsoleLogHandler handler = ConsoleLogHandler.private(
        BDLevel.values,
        formatter,
        (String line) => callCount++,
      );

      final BDLogRecord record = BDLogRecord(BDLevel.info, 'test');

      // Formatter returns 3 lines
      mockito
          .when(() => formatter.format(record))
          .thenReturn('Line 1\nLine 2\nLine 3');

      handler.handleRecord(record);

      expect(callCount, equals(3));
    });

    test('should handle message with error and stacktrace', () {
      final List<String> printedLines = <String>[];

      final ConsoleLogHandler handler = ConsoleLogHandler.private(
        BDLevel.values,
        const DefaultLogFormatter(),
        printedLines.add,
      );

      final BDLogRecord recordWithError = BDLogRecord(
        BDLevel.error,
        'Error occurred',
        error: Exception('Test exception'),
        stackTrace: StackTrace.current,
      );

      handler.handleRecord(recordWithError);

      // Should print multiple lines (message, error, stacktrace)
      expect(printedLines, isNotEmpty);
    });
  });

  group('supportLevel edge cases', () {
    test('should return false for all levels when supportedLevels is empty',
        () {
      final ConsoleLogHandler handler = ConsoleLogHandler(
        supportedLevels: <BDLevel>[],
      );

      for (final BDLevel level in BDLevel.values) {
        expect(handler.supportLevel(level), isFalse);
      }
    });

    test('should return true for all levels when all levels are supported', () {
      final ConsoleLogHandler handler = ConsoleLogHandler(
        // ignore: avoid_redundant_argument_values
        supportedLevels: BDLevel.values,
      );

      for (final BDLevel level in BDLevel.values) {
        expect(handler.supportLevel(level), isTrue);
      }
    });
  });
}

class _MockFormatter extends mockito.Mock implements DefaultLogFormatter {}
