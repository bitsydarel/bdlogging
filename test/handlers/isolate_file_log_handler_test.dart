// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:bdlogging/src/handlers/isolate_file_log_handler.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory testDirectory;
  late String uniqueDirName;

  setUp(() {
    // Create a unique directory for each test to avoid conflicts
    uniqueDirName = 'isolate_test_${DateTime.now().microsecondsSinceEpoch}';
    testDirectory = Directory(
      path.join(Directory.current.path, 'test/resources', uniqueDirName),
    )..createSync(recursive: true);
  });

  tearDown(() async {
    // Give isolates time to finish before cleanup
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (testDirectory.existsSync()) {
      testDirectory.deleteSync(recursive: true);
    }
  });

  group('IsolateFileLogHandler', () {
    group('constructor', () {
      test('should create handler with default values', () {
        final IsolateFileLogHandler handler = IsolateFileLogHandler(
          testDirectory,
        );

        expect(handler.maxFilesCount, equals(5));
        expect(handler.logNamePrefix, equals('_log'));
        expect(handler.maxLogSizeInMb, equals(5));
        expect(
          handler.supportedLevels,
          containsAll(<BDLevel>[
            BDLevel.warning,
            BDLevel.success,
            BDLevel.error,
          ]),
        );

        // Clean up the isolate
        handler.clean();
      });

      test('should create handler with custom values', () {
        final IsolateFileLogHandler handler = IsolateFileLogHandler(
          testDirectory,
          maxFilesCount: 10,
          logNamePrefix: 'custom_prefix',
          maxLogSizeInMb: 10,
          supportedLevels: <BDLevel>[BDLevel.debug, BDLevel.info],
        );

        expect(handler.maxFilesCount, equals(10));
        expect(handler.logNamePrefix, equals('custom_prefix'));
        expect(handler.maxLogSizeInMb, equals(10));
        expect(
          handler.supportedLevels,
          containsAll(<BDLevel>[BDLevel.debug, BDLevel.info]),
        );

        // Clean up the isolate
        handler.clean();
      });

      test('should throw assertion error when logNamePrefix is empty', () {
        expect(
          () => IsolateFileLogHandler(
            testDirectory,
            logNamePrefix: '',
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should throw assertion error when maxLogSizeInMb is zero', () {
        expect(
          () => IsolateFileLogHandler(
            testDirectory,
            maxLogSizeInMb: 0,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should throw assertion error when maxLogSizeInMb is negative', () {
        expect(
          () => IsolateFileLogHandler(
            testDirectory,
            maxLogSizeInMb: -1,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should throw assertion error when maxFilesCount is zero', () {
        expect(
          () => IsolateFileLogHandler(
            testDirectory,
            maxFilesCount: 0,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should throw assertion error when maxFilesCount is negative', () {
        expect(
          () => IsolateFileLogHandler(
            testDirectory,
            maxFilesCount: -1,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should allow maxFilesCount greater than zero', () {
        final IsolateFileLogHandler handler = IsolateFileLogHandler(
          testDirectory,
          maxFilesCount: 1,
        );

        expect(handler.maxFilesCount, equals(1));
        handler.clean();
      });
    });

    group('supportLevel', () {
      test('should return true for supported levels', () {
        final IsolateFileLogHandler handler = IsolateFileLogHandler(
          testDirectory,
          supportedLevels: <BDLevel>[
            BDLevel.warning,
            BDLevel.success,
            BDLevel.error,
          ],
        );

        expect(handler.supportLevel(BDLevel.warning), isTrue);
        expect(handler.supportLevel(BDLevel.success), isTrue);
        expect(handler.supportLevel(BDLevel.error), isTrue);

        // Clean up the isolate
        handler.clean();
      });

      test('should return false for unsupported levels', () {
        final IsolateFileLogHandler handler = IsolateFileLogHandler(
          testDirectory,
          supportedLevels: <BDLevel>[
            BDLevel.warning,
            BDLevel.success,
            BDLevel.error,
          ],
        );

        expect(handler.supportLevel(BDLevel.debug), isFalse);
        expect(handler.supportLevel(BDLevel.info), isFalse);

        // Clean up the isolate
        handler.clean();
      });

      test('should work with custom supported levels', () {
        final IsolateFileLogHandler handler = IsolateFileLogHandler(
          testDirectory,
          supportedLevels: <BDLevel>[BDLevel.debug],
        );

        expect(handler.supportLevel(BDLevel.debug), isTrue);
        expect(handler.supportLevel(BDLevel.info), isFalse);
        expect(handler.supportLevel(BDLevel.warning), isFalse);
        expect(handler.supportLevel(BDLevel.success), isFalse);
        expect(handler.supportLevel(BDLevel.error), isFalse);

        // Clean up the isolate
        handler.clean();
      });

      test('should work with all levels supported', () {
        final IsolateFileLogHandler handler = IsolateFileLogHandler(
          testDirectory,
          supportedLevels: BDLevel.values,
        );

        for (final BDLevel level in BDLevel.values) {
          expect(handler.supportLevel(level), isTrue);
        }

        // Clean up the isolate
        handler.clean();
      });

      test('should work with empty supported levels', () {
        final IsolateFileLogHandler handler = IsolateFileLogHandler(
          testDirectory,
          supportedLevels: <BDLevel>[],
        );

        for (final BDLevel level in BDLevel.values) {
          expect(handler.supportLevel(level), isFalse);
        }

        // Clean up the isolate
        handler.clean();
      });
    });
  });

  group('IsolateFileLogHandler integration tests', () {
    test('should write log record to file', () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'integration_test',
        supportedLevels: BDLevel.values,
      );

      final BDLogRecord record = BDLogRecord(
        BDLevel.error,
        'Test error message',
      );

      await handler.handleRecord(record);

      // Give the isolate time to process and write
      await Future<void>.delayed(const Duration(milliseconds: 500));

      await handler.clean();

      // Verify file was created and contains the message
      final List<FileSystemEntity> files = testDirectory.listSync();
      final List<File> logFiles = files
          .whereType<File>()
          .where((File f) => f.path.contains('integration_test'))
          .toList();

      expect(logFiles, isNotEmpty, reason: 'Log file should be created');

      final String content = logFiles.first.readAsStringSync();
      expect(content, contains('Test error message'));
    });

    test('rapid clean() calls return same future', () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'race_condition_test',
      );

      await handler.handleRecord(
        BDLogRecord(BDLevel.info, 'Test message'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));

      final Future<void> clean1 = handler.clean();
      final Future<void> clean2 = handler.clean();
      final Future<void> clean3 = handler.clean();

      await expectLater(
        Future.wait(<Future<void>>[clean1, clean2, clean3])
            .timeout(const Duration(seconds: 5)),
        completes,
      );
    });

    test('second clean() call returns existing future while pending', () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'pending_clean_test',
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));

      final Future<void> firstClean = handler.clean();
      final Future<void> secondClean = handler.clean();

      await Future.wait(<Future<void>>[firstClean, secondClean]);

      expect(handler.cleanCompleterForTesting?.isCompleted, isTrue);
    });

    test('should write multiple log records in order', () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'order_test',
        supportedLevels: BDLevel.values,
      );

      final List<BDLogRecord> records = <BDLogRecord>[
        BDLogRecord(BDLevel.info, 'First message'),
        BDLogRecord(BDLevel.warning, 'Second message'),
        BDLogRecord(BDLevel.error, 'Third message'),
      ];

      for (final BDLogRecord record in records) {
        await handler.handleRecord(record);
      }

      // Give the isolate time to process and write
      await Future<void>.delayed(const Duration(milliseconds: 500));

      await handler.clean();

      // Verify file contains all messages in order
      final List<FileSystemEntity> files = testDirectory.listSync();
      final List<File> logFiles = files
          .whereType<File>()
          .where((File f) => f.path.contains('order_test'))
          .toList();

      expect(logFiles, isNotEmpty);

      final String content = logFiles.first.readAsStringSync();
      final int firstIndex = content.indexOf('First message');
      final int secondIndex = content.indexOf('Second message');
      final int thirdIndex = content.indexOf('Third message');

      expect(firstIndex, lessThan(secondIndex));
      expect(secondIndex, lessThan(thirdIndex));
    });

    test('should buffer records sent before initialization', () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'buffered_test',
        supportedLevels: BDLevel.values,
      );

      const int recordCount = 50;
      for (int i = 0; i < recordCount; i++) {
        await handler.handleRecord(
          BDLogRecord(BDLevel.warning, 'Buffered message $i'),
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 800));
      await handler.clean();

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

    test('clean() should complete and release resources', () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'resource_cleanup_test',
      );

      await handler.handleRecord(
        BDLogRecord(BDLevel.info, 'Resource test message'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));

      await expectLater(
        handler.clean().timeout(const Duration(seconds: 5)),
        completes,
      );

      expect(handler.cleanCompleterForTesting?.isCompleted, isTrue);
    });

    test('multiple handlers can be created and cleaned sequentially', () async {
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

      expect(true, isTrue);
    });

    test('log records should be written in order', () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'ordering_test',
        supportedLevels: BDLevel.values,
      );

      for (int i = 0; i < 20; i++) {
        await handler.handleRecord(
          BDLogRecord(BDLevel.info, 'Ordered message $i'),
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
      await handler.clean();

      final List<File> logFiles = testDirectory
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.contains('ordering_test'))
          .toList();

      expect(logFiles, isNotEmpty);
      final String content = logFiles.first.readAsStringSync();

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

    test('should complete clean() successfully', () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'clean_test',
      );

      final BDLogRecord record = BDLogRecord(BDLevel.error, 'Test message');
      await handler.handleRecord(record);

      // Give the isolate time to process
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // clean() should complete without throwing
      await expectLater(handler.clean(), completes);
    });

    test('sending log records immediately should not error', () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'early_record_test',
        supportedLevels: BDLevel.values,
      );

      for (int i = 0; i < 10; i++) {
        await handler.handleRecord(
          BDLogRecord(BDLevel.info, 'Immediate message $i'),
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));

      await expectLater(handler.clean(), completes);

      final List<File> logFiles = testDirectory
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.contains('early_record_test'))
          .toList();

      expect(logFiles, isNotEmpty);
      final String content = logFiles.first.readAsStringSync();

      for (int i = 0; i < 10; i++) {
        expect(content, contains('Immediate message $i'));
      }
    });

    test('should handle zero records gracefully', () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'zero_records',
      );

      // Don't write any records, just clean up
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Should complete without throwing
      await expectLater(handler.clean(), completes);
    });

    test('should handle single record correctly', () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'single_record',
        supportedLevels: BDLevel.values,
      );

      final BDLogRecord record = BDLogRecord(
        BDLevel.warning,
        'Single log entry',
      );

      await handler.handleRecord(record);

      // Give the isolate time to process
      await Future<void>.delayed(const Duration(milliseconds: 500));

      await handler.clean();

      // Verify file was created with the single entry
      final List<FileSystemEntity> files = testDirectory.listSync();
      final List<File> logFiles = files
          .whereType<File>()
          .where((File f) => f.path.contains('single_record'))
          .toList();

      expect(logFiles, hasLength(1));
      expect(logFiles.first.readAsStringSync(), contains('Single log entry'));
    });

    test('should handle many records correctly', () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'many_records',
        supportedLevels: BDLevel.values,
      );

      const int recordCount = 50;
      for (int i = 0; i < recordCount; i++) {
        await handler.handleRecord(
          BDLogRecord(BDLevel.info, 'Log message $i'),
        );
      }

      // Give the isolate time to process all records
      await Future<void>.delayed(const Duration(milliseconds: 1000));

      await handler.clean();

      // Verify file contains all messages
      final List<FileSystemEntity> files = testDirectory.listSync();
      final List<File> logFiles = files
          .whereType<File>()
          .where((File f) => f.path.contains('many_records'))
          .toList();

      expect(logFiles, isNotEmpty);

      final String content = logFiles.first.readAsStringSync();

      // Check that all messages are present
      for (int i = 0; i < recordCount; i++) {
        expect(content, contains('Log message $i'));
      }
    });

    test('should handle log record with error and stacktrace', () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'error_stacktrace',
        supportedLevels: BDLevel.values,
      );

      final Exception testError = Exception('Test exception');
      final StackTrace testStackTrace = StackTrace.current;

      final BDLogRecord record = BDLogRecord(
        BDLevel.error,
        'Error with stacktrace',
        error: testError,
        stackTrace: testStackTrace,
      );

      await handler.handleRecord(record);

      // Give the isolate time to process
      await Future<void>.delayed(const Duration(milliseconds: 500));

      await handler.clean();

      // Verify file contains the error message
      final List<FileSystemEntity> files = testDirectory.listSync();
      final List<File> logFiles = files
          .whereType<File>()
          .where((File f) => f.path.contains('error_stacktrace'))
          .toList();

      expect(logFiles, isNotEmpty);
      expect(
        logFiles.first.readAsStringSync(),
        contains('Error with stacktrace'),
      );
    });

    test('should handle isolate communication failures gracefully', () async {
      final List<String> loggedMessages = <String>[];
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'isolate_failure',
        logFunction: (String message, {Object? error, StackTrace? stackTrace}) {
          loggedMessages.add(message);
        },
      );

      // Simulate sending invalid data to isolate
      // This tests the error handling in handlePortMessage
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Try to send invalid message to isolate port
      try {
        handler.handlePortMessage('invalid_message', Completer<SendPort>());
      } on Object catch (_) {
        // Expected to fail or be handled
      }

      await handler.clean();

      // Should have logged isolate errors
      expect(loggedMessages, isNotEmpty);
    });

    test('should recover from handler failures during isolate initialization',
        () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'recovery_test',
        supportedLevels: BDLevel.values,
      );

      // Send a record before isolate is fully initialized
      await handler.handleRecord(BDLogRecord(BDLevel.info, 'Early record'));

      // Wait for isolate to initialize and process
      await Future<void>.delayed(const Duration(milliseconds: 800));

      // Send more records - should work despite early record
      await handler.handleRecord(BDLogRecord(BDLevel.warning, 'Later record'));

      await Future<void>.delayed(const Duration(milliseconds: 300));
      await handler.clean();

      // Verify both records were written
      final List<File> logFiles = testDirectory
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.contains('recovery_test'))
          .toList();

      expect(logFiles, isNotEmpty);
      final String content = logFiles.first.readAsStringSync();
      expect(content, contains('Early record'));
      expect(content, contains('Later record'));
    });

    test('should handle concurrent handler operations', () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'concurrent_test',
        supportedLevels: BDLevel.values,
      );

      // Send multiple records concurrently
      final List<Future<void>> futures = <Future<void>>[];
      for (int i = 0; i < 20; i++) {
        futures.add(
            handler.handleRecord(BDLogRecord(BDLevel.info, 'Concurrent $i')));
      }

      await Future.wait(futures);
      await Future<void>.delayed(const Duration(milliseconds: 1000));

      await handler.clean();

      // Verify all records were processed
      final List<File> logFiles = testDirectory
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.contains('concurrent_test'))
          .toList();

      expect(logFiles, isNotEmpty);
      final String content = logFiles.first.readAsStringSync();

      for (int i = 0; i < 20; i++) {
        expect(content, contains('Concurrent $i'));
      }
    });

    test('clean command before initialization does not throw', () async {
      final Directory localDir = Directory(
        path.join(
          Directory.current.path,
          'test/resources/coverage_clean_${DateTime.now().microsecondsSinceEpoch}',
        ),
      )..createSync(recursive: true);

      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        localDir,
        logNamePrefix: 'coverage_clean',
      );

      await handler.clean();
      expect(handler.cleanCompleterForTesting?.isCompleted, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (localDir.existsSync()) {
        localDir.deleteSync(recursive: true);
      }
    });
  });

  group('IsolateFileLogHandler error handling', () {
    test('handlePortError should call log function with error details', () {
      String? loggedMessage;
      Object? loggedError;
      StackTrace? loggedStackTrace;

      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'error_handler_test',
        logFunction: (
          String message, {
          Object? error,
          StackTrace? stackTrace,
        }) {
          loggedMessage = message;
          loggedError = error;
          loggedStackTrace = stackTrace;
        },
      );

      final Exception testException = Exception('Test error');
      final StackTrace testStackTrace = StackTrace.current;

      handler.handlePortError(testException, testStackTrace);

      expect(loggedMessage, equals('IsolateFileLogHandler.onError'));
      expect(loggedError, equals(testException));
      expect(loggedStackTrace, equals(testStackTrace));

      // Clean up
      handler.clean();
    });

    test('handlePortError should handle different error types', () {
      final List<Object?> loggedErrors = <Object?>[];

      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'error_types_test',
        logFunction: (
          String message, {
          Object? error,
          StackTrace? stackTrace,
        }) {
          loggedErrors.add(error);
        },
      );

      // Test with Exception
      handler.handlePortError(Exception('exception'), StackTrace.empty);
      expect(loggedErrors.last, isA<Exception>());

      // Test with Error
      handler.handlePortError(StateError('state error'), StackTrace.empty);
      expect(loggedErrors.last, isA<StateError>());

      // Test with String
      handler.handlePortError('string error', StackTrace.empty);
      expect(loggedErrors.last, equals('string error'));

      // Test with int (unusual but possible)
      handler.handlePortError(42, StackTrace.empty);
      expect(loggedErrors.last, equals(42));

      // Clean up
      handler.clean();
    });

    test('handlePortDone should call log function with done message', () {
      String? loggedMessage;

      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'done_handler_test',
        logFunction: (
          String message, {
          Object? error,
          StackTrace? stackTrace,
        }) {
          loggedMessage = message;
        },
      );

      handler.handlePortDone();

      expect(loggedMessage, equals('IsolateFileLogHandler done'));

      // Clean up
      handler.clean();
    });

    test('handlePortDone should not pass error or stackTrace', () {
      Object? loggedError;
      StackTrace? loggedStackTrace;

      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'done_no_error_test',
        logFunction: (
          String message, {
          Object? error,
          StackTrace? stackTrace,
        }) {
          loggedError = error;
          loggedStackTrace = stackTrace;
        },
      );

      handler.handlePortDone();

      expect(loggedError, isNull);
      expect(loggedStackTrace, isNull);

      // Clean up
      handler.clean();
    });

    test('custom logFunction should be used instead of default', () {
      int callCount = 0;

      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'custom_log_test',
        logFunction: (
          String message, {
          Object? error,
          StackTrace? stackTrace,
        }) {
          callCount++;
        },
      );

      handler.handlePortError(Exception('test'), StackTrace.empty);
      handler.handlePortDone();

      expect(callCount, equals(2));

      // Clean up
      handler.clean();
    });
  });

  group('IsolateFileLogHandler error port handling', () {
    test('handleErrorPortMessage logs isolate error and completes completer',
        () async {
      final List<String> loggedMessages = <String>[];
      final List<Object?> loggedErrors = <Object?>[];
      final List<StackTrace?> loggedStackTraces = <StackTrace?>[];

      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'error_port_error',
        logFunction: (
          String message, {
          Object? error,
          StackTrace? stackTrace,
        }) {
          loggedMessages.add(message);
          loggedErrors.add(error);
          loggedStackTraces.add(stackTrace);
        },
      );

      final Completer<SendPort> sendPortCompleter = Completer<SendPort>();
      final StateError testError = StateError('boom');
      final StackTrace testStackTrace = StackTrace.current;

      handler.handleErrorPortMessage(
        <Object?>[testError, testStackTrace.toString()],
        sendPortCompleter,
      );

      expect(loggedMessages, contains('IsolateFileLogHandler.onError'));
      expect(loggedErrors, contains(testError));
      expect(
        loggedStackTraces.whereType<StackTrace>().isNotEmpty,
        isTrue,
      );

      await expectLater(sendPortCompleter.future, throwsA(isA<StateError>()));

      await handler.clean();
    });

    test('handleErrorPortMessage logs exit before init and errors', () async {
      final List<String> loggedMessages = <String>[];

      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'error_port_exit_before',
        logFunction: (
          String message, {
          Object? error,
          StackTrace? stackTrace,
        }) {
          loggedMessages.add(message);
        },
      );

      final Completer<SendPort> sendPortCompleter = Completer<SendPort>();

      handler.handleErrorPortMessage(null, sendPortCompleter);

      expect(
        loggedMessages,
        contains('IsolateFileLogHandler.onExitBeforeInit'),
      );
      await expectLater(
        sendPortCompleter.future,
        throwsA(isA<StateError>()),
      );

      await handler.clean();
    });

    test('handleErrorPortMessage logs exit after clean as info', () async {
      final List<String> loggedMessages = <String>[];

      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'error_port_exit_clean',
        logFunction: (
          String message, {
          Object? error,
          StackTrace? stackTrace,
        }) {
          loggedMessages.add(message);
        },
      );

      final ReceivePort mockReceivePort = ReceivePort();
      final Completer<SendPort> sendPortCompleter = Completer<SendPort>();
      sendPortCompleter.complete(mockReceivePort.sendPort);

      handler.cleanStateForTesting = 'completed';
      handler.handleErrorPortMessage(null, sendPortCompleter);

      expect(loggedMessages, contains('IsolateFileLogHandler.onExit'));

      mockReceivePort.close();
      await handler.clean();
    });

    test('handleErrorPortMessage logs unexpected exit', () async {
      final List<String> loggedMessages = <String>[];

      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'error_port_exit_unexpected',
        logFunction: (
          String message, {
          Object? error,
          StackTrace? stackTrace,
        }) {
          loggedMessages.add(message);
        },
      );

      final ReceivePort mockReceivePort = ReceivePort();
      final Completer<SendPort> sendPortCompleter = Completer<SendPort>();
      sendPortCompleter.complete(mockReceivePort.sendPort);

      handler.cleanStateForTesting = 'requested';
      handler.handleErrorPortMessage(null, sendPortCompleter);

      expect(
        loggedMessages,
        contains('IsolateFileLogHandler.onExitUnexpected'),
      );

      mockReceivePort.close();
      await handler.clean();
    });

    test('handleErrorPortMessage logs unexpected exit after clean failure',
        () async {
      final List<String> loggedMessages = <String>[];

      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'error_port_exit_failed',
        logFunction: (
          String message, {
          Object? error,
          StackTrace? stackTrace,
        }) {
          loggedMessages.add(message);
        },
      );

      final ReceivePort mockReceivePort = ReceivePort();
      final Completer<SendPort> sendPortCompleter = Completer<SendPort>();
      sendPortCompleter.complete(mockReceivePort.sendPort);

      handler.cleanStateForTesting = 'failed';
      handler.handleErrorPortMessage(null, sendPortCompleter);

      expect(
        loggedMessages,
        contains('IsolateFileLogHandler.onExitUnexpected'),
      );

      mockReceivePort.close();
      await handler.clean();
    });

    test('handleErrorPortMessage ignores unknown message types', () async {
      final List<String> loggedMessages = <String>[];

      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'error_port_unknown',
        logFunction: (
          String message, {
          Object? error,
          StackTrace? stackTrace,
        }) {
          loggedMessages.add(message);
        },
      );

      final Completer<SendPort> sendPortCompleter = Completer<SendPort>();

      handler.handleErrorPortMessage('unexpected_message', sendPortCompleter);

      expect(loggedMessages, isEmpty);
      expect(sendPortCompleter.isCompleted, isFalse);

      await handler.clean();
    });
  });

  group('IsolateFileLogHandler Completer guards', () {
    test(
        'handlePortMessage should not throw when SendPort received '
        'multiple times', () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'sendport_guard_test',
      );

      // Wait for the handler to initialize and get the sendPortCompleter
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final Completer<SendPort>? sendPortCompleter =
          handler.sendPortCompleterForTesting;
      expect(sendPortCompleter, isNotNull);
      expect(sendPortCompleter!.isCompleted, isTrue);

      // Create a mock SendPort to simulate duplicate message
      final ReceivePort mockReceivePort = ReceivePort();
      final SendPort mockSendPort = mockReceivePort.sendPort;

      // This should NOT throw even though the completer is already completed
      // The guard should prevent the second complete() call
      expect(
        () => handler.handlePortMessage(mockSendPort, sendPortCompleter),
        returnsNormally,
      );

      // Verify completer is still completed (not reset)
      expect(sendPortCompleter.isCompleted, isTrue);

      // Clean up
      mockReceivePort.close();
      handler.clean();
    });

    test(
        'handlePortMessage should not throw when cleanCompletedMessage '
        'received multiple times', () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'clean_guard_test',
      );

      // Wait for the handler to initialize
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Set up a clean completer to simulate clean() was called
      final Completer<void> cleanCompleter = Completer<void>();
      handler.cleanCompleterForTesting = cleanCompleter;

      // Get the sendPortCompleter for the handlePortMessage call
      final Completer<SendPort> sendPortCompleter = Completer<SendPort>();

      // First cleanCompletedMessage should complete the completer
      handler.handlePortMessage(cleanCompletedMessage, sendPortCompleter);
      expect(cleanCompleter.isCompleted, isTrue);

      // Second cleanCompletedMessage should NOT throw
      // The guard should prevent the second complete() call
      expect(
        () =>
            handler.handlePortMessage(cleanCompletedMessage, sendPortCompleter),
        returnsNormally,
      );

      // Clean up
      handler.clean();
    });

    test(
        'handlePortMessage should handle cleanCompletedMessage '
        'when cleanCompleter is null', () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'null_clean_test',
      );

      // Wait for the handler to initialize
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Ensure cleanCompleter is null
      handler.cleanCompleterForTesting = null;
      expect(handler.cleanCompleterForTesting, isNull);

      // Get the sendPortCompleter for the handlePortMessage call
      final Completer<SendPort> sendPortCompleter = Completer<SendPort>();

      // cleanCompletedMessage should NOT throw even when cleanCompleter is null
      expect(
        () =>
            handler.handlePortMessage(cleanCompletedMessage, sendPortCompleter),
        returnsNormally,
      );

      // Clean up
      handler.clean();
    });

    test('sendPortCompleter guard prevents StateError on duplicate SendPort',
        () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'state_error_test',
      );

      // Wait for the handler to initialize
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Create a fresh completer that's already completed
      final Completer<SendPort> alreadyCompletedCompleter =
          Completer<SendPort>();
      final ReceivePort mockReceivePort = ReceivePort();
      alreadyCompletedCompleter.complete(mockReceivePort.sendPort);

      // Wait for the future to complete
      await alreadyCompletedCompleter.future;

      // Create another mock SendPort
      final ReceivePort anotherMockReceivePort = ReceivePort();
      final SendPort anotherMockSendPort = anotherMockReceivePort.sendPort;

      // Without the guard, this would throw:
      // StateError: Future already completed
      expect(
        () => handler.handlePortMessage(
          anotherMockSendPort,
          alreadyCompletedCompleter,
        ),
        returnsNormally,
      );

      // Clean up
      mockReceivePort.close();
      anotherMockReceivePort.close();
      handler.clean();
    });

    test('cleanCompleter guard prevents StateError on duplicate clean message',
        () async {
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'clean_state_error',
      );

      // Wait for the handler to initialize
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Create a fresh completer that's already completed
      final Completer<void> alreadyCompletedCleanCompleter = Completer<void>();
      alreadyCompletedCleanCompleter.complete();

      // Wait for the future to complete
      await alreadyCompletedCleanCompleter.future;

      // Set it as the handler's cleanCompleter
      handler.cleanCompleterForTesting = alreadyCompletedCleanCompleter;

      final Completer<SendPort> sendPortCompleter = Completer<SendPort>();

      // Without the guard, this would throw:
      // StateError: Future already completed
      expect(
        () => handler.handlePortMessage(
          cleanCompletedMessage,
          sendPortCompleter,
        ),
        returnsNormally,
      );

      // Clean up
      handler.clean();
    });
  });

  group('IsolateFileLogHandler Completer guards integration tests', () {
    test('full lifecycle with multiple log records completes successfully',
        () async {
      // Arrange: Create handler with unique prefix
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'full_lifecycle',
        supportedLevels: BDLevel.values,
      );

      // Prepare multiple log records with different levels and content
      final List<BDLogRecord> records = <BDLogRecord>[
        BDLogRecord(BDLevel.debug, 'Debug message for lifecycle test'),
        BDLogRecord(BDLevel.info, 'Info message for lifecycle test'),
        BDLogRecord(BDLevel.warning, 'Warning message for lifecycle test'),
        BDLogRecord(BDLevel.success, 'Success message for lifecycle test'),
        BDLogRecord(
          BDLevel.error,
          'Error message for lifecycle test',
          error: Exception('Test exception'),
          stackTrace: StackTrace.current,
        ),
      ];

      // Act: Send all log records
      for (final BDLogRecord record in records) {
        await handler.handleRecord(record);
      }

      // Wait for isolate to process all records
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Verify sendPortCompleter is completed (isolate initialized)
      expect(handler.sendPortCompleterForTesting, isNotNull);
      expect(handler.sendPortCompleterForTesting!.isCompleted, isTrue);

      // Call clean() and verify it completes
      await expectLater(handler.clean(), completes);

      // Verify cleanCompleter is completed
      expect(handler.cleanCompleterForTesting, isNotNull);
      expect(handler.cleanCompleterForTesting!.isCompleted, isTrue);

      // Verify log file exists and contains all expected messages
      final List<FileSystemEntity> files = testDirectory.listSync();
      final List<File> logFiles = files
          .whereType<File>()
          .where((File f) => f.path.contains('full_lifecycle'))
          .toList();

      expect(logFiles, isNotEmpty, reason: 'Log file should be created');

      final String content = logFiles.first.readAsStringSync();
      expect(content, contains('Debug message for lifecycle test'));
      expect(content, contains('Info message for lifecycle test'));
      expect(content, contains('Warning message for lifecycle test'));
      expect(content, contains('Success message for lifecycle test'));
      expect(content, contains('Error message for lifecycle test'));

      // Verify message ordering
      final int debugIndex = content.indexOf('Debug message');
      final int infoIndex = content.indexOf('Info message');
      final int warningIndex = content.indexOf('Warning message');
      final int successIndex = content.indexOf('Success message');
      final int errorIndex = content.indexOf('Error message');

      expect(debugIndex, lessThan(infoIndex));
      expect(infoIndex, lessThan(warningIndex));
      expect(warningIndex, lessThan(successIndex));
      expect(successIndex, lessThan(errorIndex));
    });

    test('rapid clean() calls do not cause StateError', () async {
      // Arrange: Create handler and send a log record
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'rapid_clean',
        supportedLevels: BDLevel.values,
      );

      await handler.handleRecord(
        BDLogRecord(BDLevel.info, 'Message before rapid clean'),
      );

      // Wait for isolate to initialize and process
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Act: Call clean() multiple times rapidly without awaiting between calls
      // This tests the guard against completing an already completed Completer
      final List<Future<void>> cleanFutures = <Future<void>>[];

      // First clean() - this should work normally
      cleanFutures.add(handler.clean());

      // Additional rapid calls - these create new Completers
      // The guard should prevent StateError if cleanCompletedMessage arrives
      // after the Completer was already completed
      for (int i = 0; i < 3; i++) {
        // Small delay to allow message processing between calls
        await Future<void>.delayed(const Duration(milliseconds: 10));
        try {
          cleanFutures.add(handler.clean());
        } on Exception {
          // It's acceptable if subsequent clean() calls fail
          // The important thing is no StateError from the Completer guard
        }
      }

      // Assert: At least the first clean() should complete without StateError
      // We use a timeout to prevent hanging if something goes wrong
      bool firstCleanCompleted = false;
      Object? caughtError;

      try {
        await cleanFutures.first.timeout(const Duration(seconds: 5));
        firstCleanCompleted = true;
      } on Exception catch (e) {
        caughtError = e;
      }

      expect(
        firstCleanCompleted,
        isTrue,
        reason: 'First clean() should complete. Error: $caughtError',
      );

      // Verify no StateError was thrown (would have propagated)
      expect(caughtError, isNot(isA<StateError>()));
    });

    test('stress test: many concurrent handlers complete successfully',
        () async {
      // Arrange: Create multiple handlers with unique prefixes
      const int handlerCount = 10;
      final List<IsolateFileLogHandler> handlers = <IsolateFileLogHandler>[];

      for (int i = 0; i < handlerCount; i++) {
        handlers.add(
          IsolateFileLogHandler(
            testDirectory,
            logNamePrefix: 'stress_handler_$i',
            supportedLevels: BDLevel.values,
          ),
        );
      }

      // Act: Send log records to all handlers concurrently
      final List<Future<void>> sendFutures = <Future<void>>[];
      for (int i = 0; i < handlers.length; i++) {
        sendFutures.add(
          handlers[i].handleRecord(
            BDLogRecord(BDLevel.info, 'Stress test message from handler $i'),
          ),
        );
      }
      await Future.wait(sendFutures);

      // Wait for all isolates to process
      await Future<void>.delayed(const Duration(milliseconds: 800));

      // Call clean() on all handlers concurrently
      final List<Future<void>> cleanFutures = <Future<void>>[];
      for (final IsolateFileLogHandler handler in handlers) {
        cleanFutures.add(handler.clean());
      }

      // Assert: All clean() futures should complete without StateError
      Object? caughtError;
      try {
        await Future.wait(cleanFutures).timeout(const Duration(seconds: 10));
      } on Exception catch (e) {
        caughtError = e;
      }

      expect(
        caughtError,
        isNull,
        reason: 'All handlers should complete without error. Got: $caughtError',
      );

      // Verify all log files were created
      final List<FileSystemEntity> files = testDirectory.listSync();
      for (int i = 0; i < handlerCount; i++) {
        final List<File> handlerLogFiles = files
            .whereType<File>()
            .where((File f) => f.path.contains('stress_handler_$i'))
            .toList();

        expect(
          handlerLogFiles,
          isNotEmpty,
          reason: 'Log file for handler $i should exist',
        );

        final String content = handlerLogFiles.first.readAsStringSync();
        expect(
          content,
          contains('Stress test message from handler $i'),
          reason: 'Handler $i log should contain expected message',
        );
      }

      // Verify all sendPortCompleters are completed
      for (int i = 0; i < handlers.length; i++) {
        expect(
          handlers[i].sendPortCompleterForTesting?.isCompleted,
          isTrue,
          reason: 'Handler $i sendPortCompleter should be completed',
        );
      }
    });

    test('handler survives isolate exit messages after clean()', () async {
      // Arrange: Create handler and send log records
      final List<String> logMessages = <String>[];
      final IsolateFileLogHandler handler = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'isolate_exit',
        supportedLevels: BDLevel.values,
        logFunction: (
          String message, {
          Object? error,
          StackTrace? stackTrace,
        }) {
          logMessages.add(message);
        },
      );

      await handler.handleRecord(
        BDLogRecord(BDLevel.info, 'Message before isolate exit'),
      );

      // Wait for processing
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Act: Call clean() which kills the isolate
      // The isolate exit will send a null message to the port (onExit)
      // The guard should handle this gracefully
      await expectLater(
        handler.clean().timeout(const Duration(seconds: 5)),
        completes,
      );

      // Give time for any additional exit messages to arrive
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Assert: Handler completed successfully
      expect(handler.cleanCompleterForTesting?.isCompleted, isTrue);

      // Verify log file was created
      final List<FileSystemEntity> files = testDirectory.listSync();
      final List<File> logFiles = files
          .whereType<File>()
          .where((File f) => f.path.contains('isolate_exit'))
          .toList();

      expect(logFiles, isNotEmpty);
      expect(
        logFiles.first.readAsStringSync(),
        contains('Message before isolate exit'),
      );

      // If handlePortDone was called (isolate exit), it should have logged
      // This is expected behavior, not an error
      // The key is that no StateError occurred
    });

    test('back-to-back handler creation and cleanup works correctly', () async {
      // First handler lifecycle
      final IsolateFileLogHandler handler1 = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'backtoback_session1',
        supportedLevels: BDLevel.values,
      );

      await handler1.handleRecord(
        BDLogRecord(BDLevel.info, 'Session 1 message'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 300));
      await handler1.clean();

      // Verify first handler completed
      expect(handler1.cleanCompleterForTesting?.isCompleted, isTrue);

      // Second handler lifecycle (same pattern, different prefix)
      final IsolateFileLogHandler handler2 = IsolateFileLogHandler(
        testDirectory,
        logNamePrefix: 'backtoback_session2',
        supportedLevels: BDLevel.values,
      );

      await handler2.handleRecord(
        BDLogRecord(BDLevel.info, 'Session 2 message'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 300));
      await handler2.clean();

      // Verify second handler completed
      expect(handler2.cleanCompleterForTesting?.isCompleted, isTrue);

      // Verify both log files exist with correct content
      final List<FileSystemEntity> files = testDirectory.listSync();

      final List<File> session1Files = files
          .whereType<File>()
          .where((File f) => f.path.contains('backtoback_session1'))
          .toList();
      final List<File> session2Files = files
          .whereType<File>()
          .where((File f) => f.path.contains('backtoback_session2'))
          .toList();

      expect(session1Files, isNotEmpty, reason: 'Session 1 log should exist');
      expect(session2Files, isNotEmpty, reason: 'Session 2 log should exist');

      expect(
        session1Files.first.readAsStringSync(),
        contains('Session 1 message'),
      );
      expect(
        session2Files.first.readAsStringSync(),
        contains('Session 2 message'),
      );

      // Verify no state bleeding - session 1 log should NOT contain session 2
      expect(
        session1Files.first.readAsStringSync(),
        isNot(contains('Session 2 message')),
      );
      expect(
        session2Files.first.readAsStringSync(),
        isNot(contains('Session 1 message')),
      );
    });
  });
}
