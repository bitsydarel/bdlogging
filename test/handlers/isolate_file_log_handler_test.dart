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
}
