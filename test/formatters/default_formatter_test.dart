import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:bdlogging/src/formatters/default_log_formatter.dart';
import 'package:intl/intl.dart';
import 'package:test/test.dart';

void main() {
  const String newLine = '\n';

  bool isOrdered(String log, String leading, String trailing) {
    final int leadingIndex = log.lastIndexOf(leading);
    final int trailingIndex = log.lastIndexOf(trailing);
    return trailingIndex > leadingIndex;
  }

  group('format', () {
    test(
      'should have date and time at the beginning',
      () {
        const DefaultLogFormatter formatter = DefaultLogFormatter();

        final BDLogRecord record = BDLogRecord(BDLevel.debug, 'Lorem ipsum');
        final String formattedLog = formatter.format(record);
        final String time = DateFormat('dd-MM-yyyy H:m:s').format(record.time);

        expect(formattedLog, startsWith('$newLine$time'));
      },
    );

    test('should have log record level after date and time', () {
      const DefaultLogFormatter formatter = DefaultLogFormatter();
      final BDLogRecord record = BDLogRecord(BDLevel.debug, 'Lorem ipsum');

      final String formattedLog = formatter.format(record);

      final bool result =
          isOrdered(formattedLog, record.time.toString(), record.level.label);

      expect(result, true);
    });

    test('should have log message after level', () {
      const DefaultLogFormatter formatter = DefaultLogFormatter();
      final BDLogRecord record = BDLogRecord(BDLevel.debug, 'Lorem ipsum');

      final String formattedLog = formatter.format(record);

      final bool result =
          isOrdered(formattedLog, record.level.label, record.message);

      expect(result, true);
    });

    test('should have error message after log message if error != null', () {
      const DefaultLogFormatter formatter = DefaultLogFormatter();

      final BDLogRecord record = BDLogRecord(
        BDLevel.debug,
        'Lorem ipsum',
        error: 'something bad happened',
      );

      final String formattedLog = formatter.format(record);

      if (record.error != null) {
        final String error = record.error.toString();
        final bool result = isOrdered(formattedLog, record.message, error);
        expect(result, isTrue);
      }
    });

    test('should have stacktrace after error if both are not null', () {
      const DefaultLogFormatter formatter = DefaultLogFormatter();

      final BDLogRecord record = BDLogRecord(
        BDLevel.debug,
        'Lorem ipsum',
        error: 'something bad happened',
        stackTrace: StackTrace.current,
      );

      final String formattedLog = formatter.format(record);

      if (record.error != null && record.stackTrace != null) {
        final String stacktrace = record.stackTrace.toString();
        final String error = record.error.toString();

        final bool result = isOrdered(formattedLog, error, stacktrace);

        expect(result, true);
      }
    });

    test('formatter should produce consistent output format', () {
      const DefaultLogFormatter formatter = DefaultLogFormatter();

      final BDLogRecord record1 = BDLogRecord(BDLevel.info, 'Message 1');
      final BDLogRecord record2 = BDLogRecord(BDLevel.info, 'Message 2');

      final String formatted1 = formatter.format(record1);
      final String formatted2 = formatter.format(record2);

      final RegExp datePattern =
          RegExp(r'\d{2}-\d{2}-\d{4} \d{1,2}:\d{1,2}:\d{1,2}');

      expect(datePattern.hasMatch(formatted1), isTrue);
      expect(datePattern.hasMatch(formatted2), isTrue);
    });

    test('formatter should handle many records efficiently', () {
      const DefaultLogFormatter formatter = DefaultLogFormatter();
      final Stopwatch stopwatch = Stopwatch()..start();

      for (int i = 0; i < 1000; i++) {
        formatter.format(BDLogRecord(BDLevel.info, 'Message $i'));
      }

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });
}
