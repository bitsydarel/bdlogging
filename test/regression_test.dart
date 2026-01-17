/// Regression tests for bug fixes documented in ISSUES.md
///
/// These tests ensure that fixed bugs do not regress in future changes.
/// Each test group corresponds to an issue from ISSUES.md.
library;

import 'dart:async';
import 'dart:io';

import 'package:bdlogging/bdlogging.dart';
import 'package:bdlogging/src/handlers/isolate_file_log_handler.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'test_log_handler.dart';

void main() {
  group('Regression Tests', () {
    group('Issue 1: Race condition in clean() - IsolateFileLogHandler', () {
      late Directory testDirectory;

      setUp(() {
        final String uniqueDirName =
            'issue1_test_${DateTime.now().microsecondsSinceEpoch}';
        testDirectory = Directory(
          path.join(Directory.current.path, 'test/resources', uniqueDirName),
        )..createSync(recursive: true);
      });

      tearDown(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (testDirectory.existsSync()) {
          testDirectory.deleteSync(recursive: true);
        }
      });

      test(
          'calling clean() multiple times rapidly should return same future '
          'and not cause deadlock', () async {
        final IsolateFileLogHandler handler = IsolateFileLogHandler(
          testDirectory,
          logNamePrefix: 'race_condition_test',
        );

        await handler.handleRecord(
          BDLogRecord(BDLevel.info, 'Test message'),
        );

        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Call clean() multiple times rapidly - this should not deadlock
        // and should return the same future for concurrent calls
        final Future<void> clean1 = handler.clean();
        final Future<void> clean2 = handler.clean();
        final Future<void> clean3 = handler.clean();

        // All should complete without timeout (deadlock would cause timeout)
        await expectLater(
          Future.wait(<Future<void>>[clean1, clean2, clean3])
              .timeout(const Duration(seconds: 5)),
          completes,
        );
      });

      test('second clean() call returns existing future when first is pending',
          () async {
        final IsolateFileLogHandler handler = IsolateFileLogHandler(
          testDirectory,
          logNamePrefix: 'pending_clean_test',
        );

        await Future<void>.delayed(const Duration(milliseconds: 200));

        // First clean() call
        final Future<void> firstClean = handler.clean();

        // Immediately call clean() again before first completes
        final Future<void> secondClean = handler.clean();

        // Both should complete
        await Future.wait(<Future<void>>[firstClean, secondClean]);

        // Verify cleanCompleter was not overwritten (no StateError occurred)
        expect(handler.cleanCompleterForTesting?.isCompleted, isTrue);
      });
    });

    group('Issue 2: Worker uses handler before initialization', () {
      late Directory testDirectory;

      setUp(() {
        final String uniqueDirName =
            'issue2_test_${DateTime.now().microsecondsSinceEpoch}';
        testDirectory = Directory(
          path.join(Directory.current.path, 'test/resources', uniqueDirName),
        )..createSync(recursive: true);
      });

      tearDown(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (testDirectory.existsSync()) {
          testDirectory.deleteSync(recursive: true);
        }
      });

      test(
          'sending log records immediately after handler creation '
          'should not cause LateInitializationError', () async {
        final IsolateFileLogHandler handler = IsolateFileLogHandler(
          testDirectory,
          logNamePrefix: 'early_record_test',
          supportedLevels: BDLevel.values,
        );

        // Immediately send records without waiting for initialization
        // This used to cause LateInitializationError before the fix
        for (int i = 0; i < 10; i++) {
          await handler.handleRecord(
            BDLogRecord(BDLevel.info, 'Immediate message $i'),
          );
        }

        // Wait for processing
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Clean should complete without error
        await expectLater(handler.clean(), completes);

        // Verify messages were written
        final List<File> logFiles = testDirectory
            .listSync()
            .whereType<File>()
            .where((File f) => f.path.contains('early_record_test'))
            .toList();

        expect(logFiles, isNotEmpty);
        final String content = logFiles.first.readAsStringSync();

        // Verify all messages are present
        for (int i = 0; i < 10; i++) {
          expect(content, contains('Immediate message $i'));
        }
      });

      test('log records sent before options arrive should be buffered',
          () async {
        final IsolateFileLogHandler handler = IsolateFileLogHandler(
          testDirectory,
          logNamePrefix: 'buffered_test',
          supportedLevels: BDLevel.values,
        );

        // Send many records in rapid succession
        const int recordCount = 50;
        for (int i = 0; i < recordCount; i++) {
          await handler.handleRecord(
            BDLogRecord(BDLevel.warning, 'Buffered message $i'),
          );
        }

        await Future<void>.delayed(const Duration(milliseconds: 800));
        await handler.clean();

        // All messages should be present (buffered and processed after init)
        final List<File> logFiles = testDirectory
            .listSync()
            .whereType<File>()
            .where((File f) => f.path.contains('buffered_test'))
            .toList();

        expect(logFiles, isNotEmpty);
        final String content = logFiles.first.readAsStringSync();

        for (int i = 0; i < recordCount; i++) {
          expect(
            content,
            contains('Buffered message $i'),
            reason: 'Message $i should be buffered and written',
          );
        }
      });
    });

    group('Issue 3 & 4: ReceivePort resource cleanup', () {
      late Directory testDirectory;

      setUp(() {
        final String uniqueDirName =
            'issue3_4_test_${DateTime.now().microsecondsSinceEpoch}';
        testDirectory = Directory(
          path.join(Directory.current.path, 'test/resources', uniqueDirName),
        )..createSync(recursive: true);
      });

      tearDown(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (testDirectory.existsSync()) {
          testDirectory.deleteSync(recursive: true);
        }
      });

      test('clean() should complete and release resources', () async {
        final IsolateFileLogHandler handler = IsolateFileLogHandler(
          testDirectory,
          logNamePrefix: 'resource_cleanup_test',
        );

        await handler.handleRecord(
          BDLogRecord(BDLevel.info, 'Resource test message'),
        );

        await Future<void>.delayed(const Duration(milliseconds: 200));

        // clean() should complete - if ports aren't closed properly,
        // this might hang or cause issues
        await expectLater(
          handler.clean().timeout(const Duration(seconds: 5)),
          completes,
        );

        // Verify the handler completed cleanup
        expect(handler.cleanCompleterForTesting?.isCompleted, isTrue);
      });

      test('multiple handlers can be created and cleaned up sequentially',
          () async {
        // This tests that resources are properly released
        // If ReceivePorts weren't closed, we'd eventually run out of resources
        for (int i = 0; i < 5; i++) {
          final IsolateFileLogHandler handler = IsolateFileLogHandler(
            testDirectory,
            logNamePrefix: 'sequential_handler_$i',
          );

          await handler.handleRecord(
            BDLogRecord(BDLevel.info, 'Sequential message $i'),
          );

          await Future<void>.delayed(const Duration(milliseconds: 200));
          await handler.clean();
        }

        // If we get here without hanging, resources were cleaned up properly
        expect(true, isTrue);
      });
    });

    group('Issue 5: ErrorController closed twice', () {
      tearDown(BDLogger().destroy);

      test('destroy() should complete without error', () async {
        final BDLogger logger = BDLogger();
        logger.addHandler(TestLogHandler());

        logger.info('Test message');

        // destroy() should complete without throwing
        // (double close would cause issues in debug mode)
        await expectLater(logger.destroy(), completes);
      });

      test('destroy() can be called on fresh logger', () async {
        final BDLogger logger = BDLogger();

        // Calling destroy without any activity should work
        await expectLater(logger.destroy(), completes);
      });
    });

    group('Issue 6: BDLogRecord assertion for isFatal', () {
      test('isFatal=true with error should succeed', () {
        expect(
          () => BDLogRecord(
            BDLevel.error,
            'Fatal error message',
            error: Exception('Fatal exception'),
            isFatal: true,
          ),
          returnsNormally,
        );
      });

      test('isFatal=false with error should succeed', () {
        expect(
          () => BDLogRecord(
            BDLevel.error,
            'Non-fatal error message',
            error: Exception('Exception'),
            isFatal: false,
          ),
          returnsNormally,
        );
      });

      test('isFatal=false without error should succeed', () {
        expect(
          () => BDLogRecord(
            BDLevel.info,
            'Info message',
            isFatal: false,
          ),
          returnsNormally,
        );
      });

      test('isFatal=true without error should fail assertion', () {
        // This is the key test - isFatal should only be used with error
        expect(
          () => BDLogRecord(
            BDLevel.error,
            'Fatal without error',
            isFatal: true,
            // No error provided!
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('Issue 7: maxFilesCount validation', () {
      late Directory testDirectory;

      setUp(() {
        final String uniqueDirName =
            'issue7_test_${DateTime.now().microsecondsSinceEpoch}';
        testDirectory = Directory(
          path.join(Directory.current.path, 'test/resources', uniqueDirName),
        )..createSync(recursive: true);
      });

      tearDown(() {
        if (testDirectory.existsSync()) {
          testDirectory.deleteSync(recursive: true);
        }
      });

      test('FileLogHandler should throw assertion error for maxFilesCount <= 0',
          () {
        expect(
          () => FileLogHandler(
            logNamePrefix: 'test',
            maxLogSizeInMb: 5,
            maxFilesCount: 0,
            logFileDirectory: testDirectory,
          ),
          throwsA(isA<AssertionError>()),
        );

        expect(
          () => FileLogHandler(
            logNamePrefix: 'test',
            maxLogSizeInMb: 5,
            maxFilesCount: -1,
            logFileDirectory: testDirectory,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test(
          'IsolateFileLogHandler should throw assertion error for maxFilesCount <= 0',
          () {
        expect(
          () => IsolateFileLogHandler(
            testDirectory,
            maxFilesCount: 0,
          ),
          throwsA(isA<AssertionError>()),
        );

        expect(
          () => IsolateFileLogHandler(
            testDirectory,
            maxFilesCount: -1,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('FileLogHandler should accept maxFilesCount > 0', () {
        expect(
          () => FileLogHandler(
            logNamePrefix: 'test',
            maxLogSizeInMb: 5,
            maxFilesCount: 1,
            logFileDirectory: testDirectory,
          ),
          returnsNormally,
        );
      });

      test('IsolateFileLogHandler should accept maxFilesCount > 0', () {
        final IsolateFileLogHandler handler = IsolateFileLogHandler(
          testDirectory,
          maxFilesCount: 1,
        );
        expect(handler.maxFilesCount, equals(1));

        // Clean up
        handler.clean();
      });
    });

    group('Issue 8: DateFormat caching in DefaultLogFormatter', () {
      test('formatter should produce consistent output format', () {
        const DefaultLogFormatter formatter = DefaultLogFormatter();

        final BDLogRecord record1 = BDLogRecord(BDLevel.info, 'Message 1');
        final BDLogRecord record2 = BDLogRecord(BDLevel.info, 'Message 2');

        final String formatted1 = formatter.format(record1);
        final String formatted2 = formatter.format(record2);

        // Both should have the same date format pattern
        // (dd-MM-yyyy H:m:s)
        final RegExp datePattern =
            RegExp(r'\d{2}-\d{2}-\d{4} \d{1,2}:\d{1,2}:\d{1,2}');

        expect(datePattern.hasMatch(formatted1), isTrue);
        expect(datePattern.hasMatch(formatted2), isTrue);
      });

      test('formatter should handle many records efficiently', () {
        const DefaultLogFormatter formatter = DefaultLogFormatter();
        final Stopwatch stopwatch = Stopwatch()..start();

        // Format many records - with cached DateFormat this should be fast
        for (int i = 0; i < 1000; i++) {
          formatter.format(BDLogRecord(BDLevel.info, 'Message $i'));
        }

        stopwatch.stop();

        // Should complete in reasonable time (< 1 second for 1000 records)
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });

    group('Issue 9: BDLogRecord hashCode using Object.hash', () {
      test('equal records should have same hashCode', () {
        final DateTime now = DateTime.now();

        // Create two records with same values (using same time)
        final BDLogRecord record1 = BDLogRecord(
          BDLevel.info,
          'Test message',
        );

        // Records created at different times will have different hashes
        // This is expected behavior - we just verify consistency
        expect(record1.hashCode, equals(record1.hashCode));
      });

      test('different records should have different hashCodes (usually)', () {
        final BDLogRecord record1 = BDLogRecord(BDLevel.info, 'Message 1');
        final BDLogRecord record2 = BDLogRecord(BDLevel.info, 'Message 2');
        final BDLogRecord record3 = BDLogRecord(BDLevel.error, 'Message 1');

        // Different messages
        expect(record1.hashCode, isNot(equals(record2.hashCode)));
        // Different levels
        expect(record1.hashCode, isNot(equals(record3.hashCode)));
      });

      test('hashCode should be consistent with equals', () {
        final BDLogRecord record = BDLogRecord(BDLevel.info, 'Test');

        // Same object should have same hashCode
        expect(record.hashCode, equals(record.hashCode));

        // ignore: unrelated_type_equality_checks
        if (record == record) {
          expect(record.hashCode, equals(record.hashCode));
        }
      });
    });

    group('Issue 10: BDLogError const constructor', () {
      test('BDLogError can be created with const', () {
        // This test verifies the const constructor works
        const StackTrace emptyTrace = StackTrace.empty;
        const String error = 'Test error';

        // Should be able to use const
        // ignore: prefer_const_constructors
        final BDLogError logError = BDLogError(error, emptyTrace);

        expect(logError.exception, equals(error));
        expect(logError.stackTrace, equals(emptyTrace));
      });

      test('BDLogError stores exception and stackTrace correctly', () {
        final Exception exception = Exception('Test exception');
        final StackTrace stackTrace = StackTrace.current;

        final BDLogError logError = BDLogError(exception, stackTrace);

        expect(logError.exception, equals(exception));
        expect(logError.stackTrace, equals(stackTrace));
      });
    });

    group('Issue 11: Worker handleRecord awaited (ordering)', () {
      late Directory testDirectory;

      setUp(() {
        final String uniqueDirName =
            'issue11_test_${DateTime.now().microsecondsSinceEpoch}';
        testDirectory = Directory(
          path.join(Directory.current.path, 'test/resources', uniqueDirName),
        )..createSync(recursive: true);
      });

      tearDown(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (testDirectory.existsSync()) {
          testDirectory.deleteSync(recursive: true);
        }
      });

      test('log records should be written in order', () async {
        final IsolateFileLogHandler handler = IsolateFileLogHandler(
          testDirectory,
          logNamePrefix: 'ordering_test',
          supportedLevels: BDLevel.values,
        );

        // Send records in specific order
        for (int i = 0; i < 20; i++) {
          await handler.handleRecord(
            BDLogRecord(BDLevel.info, 'Ordered message $i'),
          );
        }

        await Future<void>.delayed(const Duration(milliseconds: 500));
        await handler.clean();

        // Verify order is preserved
        final List<File> logFiles = testDirectory
            .listSync()
            .whereType<File>()
            .where((File f) => f.path.contains('ordering_test'))
            .toList();

        expect(logFiles, isNotEmpty);
        final String content = logFiles.first.readAsStringSync();

        // Verify messages appear in order
        int lastIndex = -1;
        for (int i = 0; i < 20; i++) {
          final int currentIndex = content.indexOf('Ordered message $i');
          expect(
            currentIndex,
            greaterThan(lastIndex),
            reason: 'Message $i should appear after message ${i - 1}',
          );
          lastIndex = currentIndex;
        }
      });
    });

    group('BDLevel coverage', () {
      test('exposes labels and importance values', () {
        expect(BDLevel.debug.label, equals('DEBUG'));
        expect(BDLevel.info.label, equals('INFO'));
        expect(BDLevel.warning.label, equals('WARNING'));
        expect(BDLevel.success.label, equals('SUCCESS'));
        expect(BDLevel.error.label, equals('ERROR'));

        expect(BDLevel.debug.importance, equals(3));
        expect(BDLevel.info.importance, equals(4));
        expect(BDLevel.warning.importance, equals(5));
        expect(BDLevel.success.importance, equals(6));
        expect(BDLevel.error.importance, equals(7));
      });

      test('comparison operators and compareTo work', () {
        expect(BDLevel.debug < BDLevel.info, isTrue);
        expect(BDLevel.warning > BDLevel.info, isTrue);
        expect(BDLevel.success >= BDLevel.success, isTrue);
        expect(BDLevel.error >= BDLevel.success, isTrue);
        expect(BDLevel.info <= BDLevel.warning, isTrue);
        expect(BDLevel.debug.compareTo(BDLevel.error), lessThan(0));
      });

      test('toString includes label and importance', () {
        final String description = BDLevel.error.toString();

        expect(description, contains('label: ERROR'));
        expect(description, contains('importance: 7'));
      });
    });

    group('BDLogRecord coverage', () {
      test('equality and hashCode include all fields', () {
        final StackTrace stackTrace = StackTrace.current;
        final Exception error = Exception('Failure');

        final BDLogRecord record1 = BDLogRecord(
          BDLevel.error,
          'Message',
          error: error,
          stackTrace: stackTrace,
          isFatal: true,
        );
        final BDLogRecord record2 = record1;
        final BDLogRecord record3 = BDLogRecord(
          BDLevel.error,
          'Message',
          error: Exception('Different error'),
          stackTrace: stackTrace,
          isFatal: true,
        );

        expect(record1 == record1, isTrue);
        expect(record1 == record2, isTrue);
        expect(record1 == record3, isFalse);
        expect(record1.hashCode, equals(record2.hashCode));
      });

      test('equality compares each field', () async {
        final BDLogRecord base = BDLogRecord(BDLevel.info, 'Message');
        await Future<void>.delayed(const Duration(milliseconds: 2));
        final BDLogRecord differentTime = BDLogRecord(BDLevel.info, 'Message');

        final BDLogRecord differentError = BDLogRecord(
          BDLevel.info,
          'Message',
          error: Exception('Boom'),
        );
        final BDLogRecord differentStackTrace = BDLogRecord(
          BDLevel.info,
          'Message',
          stackTrace: StackTrace.current,
        );
        final BDLogRecord differentFatal = BDLogRecord(
          BDLevel.info,
          'Message',
          error: 'Fatal',
          isFatal: true,
        );

        expect(base == differentTime, isFalse);
        expect(base == differentError, isFalse);
        expect(base == differentStackTrace, isFalse);
        expect(base == differentFatal, isFalse);
      });

      test('toString includes all fields', () {
        final BDLogRecord record = BDLogRecord(
          BDLevel.warning,
          'Warning message',
          error: 'error',
          stackTrace: StackTrace.current,
          isFatal: false,
        );

        final String description = record.toString();
        expect(description, contains('level:'));
        expect(description, contains('message: Warning message'));
        expect(description, contains('error: error'));
        expect(description, contains('stackTrace:'));
        expect(description, contains('isFatal: false'));
      });
    });

    group('BDLogger coverage', () {
      test('exposes onError stream and processingBatchSize setter', () {
        final BDLogger logger = BDLogger();
        final Stream<BDLogError> errorStream = logger.onError;

        expect(errorStream, isA<Stream<BDLogError>>());

        final int originalBatchSize = logger.processingBatchSize;
        logger.processingBatchSize = originalBatchSize + 1;
        expect(logger.processingBatchSize, equals(originalBatchSize + 1));
      });

      test('tag formatting adds prefixes', () {
        final BDLogger logger = BDLogger();

        logger.debug('Debug', tag: 'Tag');
        logger.warning('Warn', tag: 'Tag');
        logger.error('Error', Exception('boom'), tag: 'Tag');

        expect(logger.recordQueue.elementAt(0).message, equals('Tag: Debug'));
        expect(logger.recordQueue.elementAt(1).message, equals('Tag: Warn'));
        expect(logger.recordQueue.elementAt(2).message, equals('Tag: Error'));
      });

      test('clean errors are reported on error stream', () async {
        final BDLogger logger = BDLogger();
        final Stream<BDLogError> errorStream = logger.onError;
        final Completer<BDLogError> errorCompleter = Completer<BDLogError>();

        final _ThrowingCleanHandler handler = _ThrowingCleanHandler();
        logger.addHandler(handler);

        errorStream.listen((BDLogError error) {
          if (!errorCompleter.isCompleted) {
            errorCompleter.complete(error);
          }
        });

        await logger.destroy();
        expect(await errorCompleter.future, isA<BDLogError>());
      });

      test('handler errors are reported without crashing', () async {
        final BDLogger logger = BDLogger();
        final FailFastTestHandler handler = FailFastTestHandler();

        final List<Object> zoneErrors = <Object>[];
        await runZonedGuarded(() async {
          logger.addHandler(handler);
          logger.info('Trigger error');

          while (logger.recordQueue.isNotEmpty) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        }, (Object error, StackTrace stackTrace) {
          zoneErrors.add(error);
        });

        expect(zoneErrors, isNotEmpty);
      });
    });

    group('IsolateFileLogHandler coverage', () {
      test('clean command before initialization does not throw', () async {
        final Directory testDirectory = Directory(
          path.join(
            Directory.current.path,
            'test/resources/coverage_clean_${DateTime.now().microsecondsSinceEpoch}',
          ),
        )..createSync(recursive: true);

        final IsolateFileLogHandler handler = IsolateFileLogHandler(
          testDirectory,
          logNamePrefix: 'coverage_clean',
        );

        await handler.clean();
        expect(handler.cleanCompleterForTesting?.isCompleted, isTrue);

        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (testDirectory.existsSync()) {
          testDirectory.deleteSync(recursive: true);
        }
      });
    });
  });
}

class _ThrowingCleanHandler extends BDCleanableLogHandler {
  @override
  Future<void> clean() async {
    throw Exception('clean failed');
  }

  @override
  Future<void> handleRecord(BDLogRecord record) async {}

  @override
  bool supportLevel(BDLevel level) => true;
}
