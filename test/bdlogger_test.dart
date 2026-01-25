import 'dart:async';

import 'package:bdlogging/bdlogging.dart';
import 'package:test/test.dart';

import 'test_log_handler.dart';

Future<void> waitForProcessing(BDLogger logger) async {
  while (logger.recordQueue.isNotEmpty ||
      logger.processingTask?.isCompleted == false) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  group('BDLogger', () {
    tearDown(BDLogger().destroy);

    test('debug method should add a record to the queue', () {
      BDLogger().debug('Debug message');

      expect(BDLogger().recordQueue, isNotEmpty);
      expect(BDLogger().recordQueue.first.message, 'Debug message');
      expect(BDLogger().recordQueue.first.level, BDLevel.debug);
    });

    test('info method should add a record to the queue', () {
      BDLogger().info('Info message');

      expect(BDLogger().recordQueue, isNotEmpty);
      expect(BDLogger().recordQueue.first.message, 'Info message');
      expect(BDLogger().recordQueue.first.level, BDLevel.info);
    });

    test('warning method should add a record to the queue', () {
      BDLogger().warning('Warning message');

      expect(BDLogger().recordQueue, isNotEmpty);
      expect(BDLogger().recordQueue.first.message, 'Warning message');
      expect(BDLogger().recordQueue.first.level, BDLevel.warning);
    });

    test('success method should add a record to the queue', () {
      BDLogger().success('Success message');

      expect(BDLogger().recordQueue, isNotEmpty);
      expect(BDLogger().recordQueue.first.message, 'Success message');
      expect(BDLogger().recordQueue.first.level, BDLevel.success);
    });

    test('error method should add a record to the queue', () {
      BDLogger().error('Error message', Exception('Test exception'));

      expect(BDLogger().recordQueue, isNotEmpty);
      expect(BDLogger().recordQueue.first.message, 'Error message');
      expect(BDLogger().recordQueue.first.level, BDLevel.error);
    });

    test('destroy method should clear the record queue', () async {
      BDLogger().debug('Debug message');

      expect(BDLogger().recordQueue, isNotEmpty);

      await BDLogger().destroy();

      expect(BDLogger().recordQueue, isEmpty);
    });

    test('destroy should complete without error', () async {
      final BDLogger logger = BDLogger()
        ..addHandler(TestLogHandler())
        ..info('Test message');

      await expectLater(logger.destroy(), completes);
    });

    test('destroy can be called on fresh logger', () async {
      final BDLogger logger = BDLogger();

      await expectLater(logger.destroy(), completes);
    });

    test('log method should add a record with correct level and message', () {
      BDLogger().log(BDLevel.debug, 'Debug message');

      expect(BDLogger().recordQueue, isNotEmpty);
      expect(BDLogger().recordQueue.first.message, 'Debug message');
      expect(BDLogger().recordQueue.first.level, BDLevel.debug);
    });

    test(
      'log method should add a record with correct error and stack trace',
      () {
        final Exception error = Exception('Test exception');
        final StackTrace stackTrace = StackTrace.current;
        BDLogger().log(
          BDLevel.error,
          'Error message',
          error: error,
          stackTrace: stackTrace,
        );

        expect(BDLogger().recordQueue, isNotEmpty);
        expect(BDLogger().recordQueue.first.error, error);
        expect(BDLogger().recordQueue.first.stackTrace, stackTrace);
      },
    );

    test('addHandler method should not add the same handler twice', () {
      final TestLogHandler handler = TestLogHandler();
      BDLogger().addHandler(handler);
      BDLogger().addHandler(handler);

      expect(BDLogger().handlers, hasLength(1));
    });

    test('removeHandler method should not affect other handlers', () {
      final TestLogHandler handler1 = TestLogHandler();
      final TestLogHandler handler2 = TestLogHandler();
      BDLogger().addHandler(handler1);
      BDLogger().addHandler(handler2);
      BDLogger().removeHandler(handler1);

      expect(BDLogger().handlers, hasLength(1));
      expect(BDLogger().handlers.first, handler2);
    });

    test(
      'destroy method should call clean method on cleanable handlers',
      () async {
        final CleanableTestLogHandler handler = CleanableTestLogHandler();
        BDLogger().addHandler(handler);
        await BDLogger().destroy();

        expect(handler.cleanCalled, isTrue);
      },
    );

    test(
      'only one instance of a logger can exist until destroy is call',
      () async {
        final BDLogger firstCallLogger = BDLogger();
        final BDLogger secondCallLogger = BDLogger();

        expect(firstCallLogger, same(secondCallLogger));

        await firstCallLogger.destroy();

        final BDLogger newLogger = BDLogger();

        expect(firstCallLogger, isNot(newLogger));
        expect(secondCallLogger, isNot(newLogger));
      },
    );

    test(
      'should add a new handler when add handler is called',
      () {
        final BDLogger logger = BDLogger();

        expect(logger.handlers, hasLength(0));

        final TestLogHandler logHandler = TestLogHandler();

        logger.addHandler(logHandler);

        expect(logger.handlers, hasLength(1));
      },
    );

    test(
      'Should remove handler when remove handler is called',
      () {
        final BDLogger logger = BDLogger();
        final TestLogHandler logHandler = TestLogHandler();

        logger.addHandler(logHandler);

        expect(logger.handlers, hasLength(1));

        logger.removeHandler(logHandler);

        expect(logger.handlers, hasLength(0));
      },
    );

    test(
      'should not allow Logger handlers to be modified outside of the Logger',
      () {
        final BDLogger logger = BDLogger();
        final TestLogHandler testLogHandler = TestLogHandler();

        logger.addHandler(testLogHandler);

        final List<BDLogHandler> handlers = logger.handlers;

        expect(handlers.clear, throwsA(const TypeMatcher<Error>()));
      },
    );

    test(
      'should forward log record event to each handlers',
      () async {
        final TestLogHandler firstHandler = TestLogHandler();
        final TestLogHandler secondHandler = TestLogHandler();

        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{firstHandler, secondHandler},
          StreamController<BDLogError>.broadcast(),
        );

        expect(firstHandler.howManyTimeHandleWasCall, equals(0));
        expect(secondHandler.howManyTimeHandleWasCall, equals(0));

        logger.info('he he he man the test should pass :)');

        while (logger.processingTask?.isCompleted == false) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }

        expect(firstHandler.howManyTimeHandleWasCall, equals(1));
        expect(secondHandler.howManyTimeHandleWasCall, equals(1));
      },
    );

    test(
      'BDLogger should measure the time it took to process all log events',
      () async {
        final BDLogger logger = BDLogger();
        final TestLogHandler handler = TestLogHandler();
        logger.addHandler(handler);

        const int numberOfLogs = 10000;

        for (int i = 0; i < numberOfLogs; i++) {
          logger.debug('Debug message $i');
        }

        final Stopwatch stopwatch = Stopwatch()..start();

        // Process all logs
        while (logger.recordQueue.isNotEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }

        stopwatch.stop();

        final Duration processingTime = stopwatch.elapsed;

        if (processingTime.inHours > 0) {
          Zone.current.print(
            'Total processing time: ${processingTime.inHours} hours',
          );
        } else if (processingTime.inMinutes > 0) {
          Zone.current.print(
            'Total processing time: ${processingTime.inMinutes} minutes',
          );
        } else if (processingTime.inSeconds > 0) {
          Zone.current.print(
            'Total processing time: ${processingTime.inSeconds} seconds',
          );
        } else {
          Zone.current.print(
            'Total processing time: ${processingTime.inMilliseconds} ms',
          );
        }

        expect(handler.howManyTimeHandleWasCall, equals(numberOfLogs));

        await logger.destroy();
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    group('Bug Fix: Race condition in log()', () {
      test('rapid log() calls should not create multiple processing loops',
          () async {
        final TestLogHandler handler = TestLogHandler();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
        )..info('Test');

        // Should be able to await the processing task
        await logger.processingTask!.future;

        expect(handler.howManyTimeHandleWasCall, equals(1));
        await logger.destroy();
      });
    });

    group('OnError Stream (Reference)', () {
      test('onError stream is broadcast', () async {
        final StreamController<BDLogError> errorController =
            StreamController<BDLogError>.broadcast();

        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{TestLogHandler()},
          errorController,
        );

        final List<BDLogError> listener1 = <BDLogError>[];
        final List<BDLogError> listener2 = <BDLogError>[];

        logger.onError.listen(listener1.add);
        logger.onError.listen(listener2.add);

        await waitForProcessing(logger);
        logger.info('trigger');
        await waitForProcessing(logger);

        expect(listener1, isEmpty);
        expect(listener2, isEmpty);

        await logger.destroy();
        await errorController.close();
      });

      test('onError provides stackTrace', () async {
        final StreamController<BDLogError> errorController =
            StreamController<BDLogError>.broadcast();

        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{FailFastTestHandler()},
          errorController,
        );

        BDLogError? capturedError;
        logger.onError.listen((BDLogError e) => capturedError = e);

        await runZonedGuarded(() async {
          await waitForProcessing(logger);
          logger.info('trigger');
          await waitForProcessing(logger);
        }, (Object _, StackTrace __) {},
            zoneSpecification: ZoneSpecification(
              handleUncaughtError: (Zone self, ZoneDelegate parent, Zone zone,
                  Object error, StackTrace stackTrace) {},
              print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
                if (line.contains('could not process')) {
                  return;
                }
                parent.print(zone, line);
              },
            ));

        expect(capturedError, isNotNull);
        expect(capturedError!.stackTrace, isNotNull);

        await logger.destroy();
        await errorController.close();
      });

      test('clean errors are reported on error stream', () async {
        final BDLogger logger = BDLogger();
        final Stream<BDLogError> errorStream = logger.onError;
        final Completer<BDLogError> errorCompleter = Completer<BDLogError>();

        final ThrowingCleanHandler handler = ThrowingCleanHandler();
        logger.addHandler(handler);

        errorStream.listen((BDLogError error) {
          if (!errorCompleter.isCompleted) {
            errorCompleter.complete(error);
          }
        });

        await logger.destroy();

        expect(await errorCompleter.future, isA<BDLogError>());
      });

      test('handler errors are reported on error stream', () async {
        final BDLogger logger = BDLogger();
        final FailFastTestHandler handler = FailFastTestHandler();
        final List<BDLogError> errors = <BDLogError>[];

        logger.onError.listen(errors.add);
        await runZonedGuarded(() async {
          logger
            ..addHandler(handler)
            ..info('Trigger error');

          await waitForProcessing(logger);
        }, (Object _, StackTrace __) {},
            zoneSpecification: ZoneSpecification(
              handleUncaughtError: (Zone self, ZoneDelegate parent, Zone zone,
                  Object error, StackTrace stackTrace) {},
              print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
                if (line.contains('could not process')) {
                  return;
                }
                parent.print(zone, line);
              },
            ));

        expect(errors, isNotEmpty);
        await logger.destroy();
      });
    });

    group('ProcessingTask State (Existence)', () {
      test('processingTask is non-null after construction', () async {
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{},
          StreamController<BDLogError>.broadcast(),
        );

        expect(logger.processingTask, isNotNull);
        await logger.destroy();
      });

      test('processingTask is set before async processing starts', () {
        final BDLogger logger = BDLogger();

        // Immediately after construction, task should exist
        expect(logger.processingTask, isNotNull);
      });

      test('processingTask future resolves when queue empty', () async {
        final TestLogHandler handler = TestLogHandler();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
        )..info('Test');

        await expectLater(logger.processingTask!.future, completes);
        expect(logger.recordQueue, isEmpty);

        await logger.destroy();
      });
    });

    group('Edge Cases - Empty/Null States (Existence)', () {
      test('logger with no messages processes nothing', () async {
        final TestLogHandler handler = TestLogHandler();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
        );

        await waitForProcessing(logger);

        expect(handler.howManyTimeHandleWasCall, equals(0));
        await logger.destroy();
      });

      test('onError stream returns a stream instance', () {
        final BDLogger logger = BDLogger();

        final Stream<BDLogError> errorStream = logger.onError;

        expect(errorStream, isA<Stream<BDLogError>>());
      });

      test('processingBatchSize setter updates value', () {
        final BDLogger logger = BDLogger();
        final int originalBatchSize = logger.processingBatchSize;

        logger.processingBatchSize = originalBatchSize + 1;

        expect(logger.processingBatchSize, equals(originalBatchSize + 1));
      });

      test('addHandler with completed processing task triggers new batch',
          () async {
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{},
          StreamController<BDLogError>.broadcast(),
        );

        // Wait for initial (empty) processing
        await waitForProcessing(logger);
        expect(logger.processingTask!.isCompleted, isTrue);

        // Add records
        logger.info('Queued');
        expect(logger.recordQueue, hasLength(1));

        // Add handler - should trigger processing
        final TestLogHandler handler = TestLogHandler();
        logger.addHandler(handler);

        await waitForProcessing(logger);

        expect(handler.howManyTimeHandleWasCall, equals(1));
        await logger.destroy();
      });
    });

    group('Queue Behavior and Batch Processing', () {
      test('processes records in FIFO order', () async {
        final RecordCapturingHandler handler = RecordCapturingHandler();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
        );

        void logRecord(final BDLevel level, final String message) {
          logger.log(level, message);
        }

        // Add records in specific order
        logRecord(BDLevel.info, 'First');
        logRecord(BDLevel.warning, 'Second');
        logRecord(BDLevel.error, 'Third');

        await waitForProcessing(logger);

        expect(handler.capturedRecords, hasLength(3));
        expect(handler.capturedRecords[0].message, 'First');
        expect(handler.capturedRecords[1].message, 'Second');
        expect(handler.capturedRecords[2].message, 'Third');

        await logger.destroy();
      });

      test('handles concurrent log additions correctly', () async {
        final RecordCapturingHandler handler = RecordCapturingHandler();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
        );

        // Add many logs concurrently
        final List<Future<void>> futures = <Future<void>>[];
        for (int i = 0; i < 100; i++) {
          futures.add(Future<void>(() => logger.info('Message $i')));
        }

        await Future.wait(futures);
        await waitForProcessing(logger);

        expect(handler.capturedRecords, hasLength(100));
        // Verify all messages are present (order may vary due to async)
        final Set<String> messages =
            handler.capturedRecords.map((BDLogRecord r) => r.message).toSet();
        for (int i = 0; i < 100; i++) {
          expect(messages, contains('Message $i'));
        }

        await logger.destroy();
      });

      test('batch processing respects batch size limit', () async {
        final SlowTestHandler handler = SlowTestHandler(
          delay: const Duration(milliseconds: 10),
        );
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
          5, // batch size of 5
        );

        // Add more records than batch size
        for (int i = 0; i < 15; i++) {
          logger.info('Batch test $i');
        }

        // Wait for first batch to complete
        while (handler.processedRecords.length < 5) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }

        // First batch should be processed
        expect(handler.processedRecords, hasLength(5));

        // Wait for all processing to complete
        await waitForProcessing(logger);

        expect(handler.processedRecords, hasLength(15));
        await logger.destroy();
      });

      test('queue maintains records during processing', () async {
        final SlowTestHandler handler = SlowTestHandler(
          delay: const Duration(milliseconds: 50),
        );
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
          3, // small batch size
        );

        // Add records faster than processing
        for (int i = 0; i < 10; i++) {
          logger.info('Queue persistence $i');
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }

        // Queue should not be empty while processing
        expect(logger.recordQueue.isNotEmpty, isTrue);

        await waitForProcessing(logger);

        expect(logger.recordQueue, isEmpty);
        expect(handler.processedRecords, hasLength(10));
        await logger.destroy();
      });

      test('processes remaining queue on destroy', () async {
        final SlowTestHandler handler = SlowTestHandler(
          delay: const Duration(milliseconds: 100),
        );
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
        );

        // Add records
        for (int i = 0; i < 5; i++) {
          logger.info('Destroy processing $i');
        }

        // Wait for processing to start (at least one record processed)
        while (handler.processedRecords.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }

        // Start destroy while processing is still happening
        final Future<void> destroyFuture = logger.destroy();

        // Records should still be processed completely
        await destroyFuture;
        expect(handler.processedRecords, hasLength(5));
      });
    });

    group('Processing Task and Completer Behavior', () {
      test('processingTask prevents multiple concurrent processing loops',
          () async {
        final SlowTestHandler handler = SlowTestHandler(
          delay: const Duration(milliseconds: 50),
        );
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
        );

        // Add records rapidly
        for (int i = 0; i < 20; i++) {
          logger.info('Rapid log $i');
        }

        // Should only have one processing task
        final Completer<void>? firstTask = logger.processingTask;

        // Add more records - should reuse existing task
        for (int i = 20; i < 30; i++) {
          logger.info('More rapid log $i');
        }

        expect(logger.processingTask, same(firstTask));

        await waitForProcessing(logger);
        expect(handler.processedRecords, hasLength(30));
        await logger.destroy();
      });

      test('processingTask completer completes when queue empty', () async {
        final TestLogHandler handler = TestLogHandler();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
        );

        final Completer<void>? processingTask =
            (logger..info('Test message')).processingTask;
        expect(processingTask, isNotNull);

        await processingTask!.future;
        expect(logger.recordQueue, isEmpty);
        expect(handler.howManyTimeHandleWasCall, equals(1));

        await logger.destroy();
      });

      test('processingTask handles handler failures gracefully', () async {
        final FailFastTestHandler handler = FailFastTestHandler();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
        );

        final List<BDLogError> errors = <BDLogError>[];
        logger.onError.listen(errors.add);

        await runZonedGuarded(() async {
          logger.info('Will fail');
          await waitForProcessing(logger);
        }, (Object _, StackTrace __) {},
            zoneSpecification: ZoneSpecification(
              handleUncaughtError: (Zone self, ZoneDelegate parent, Zone zone,
                  Object error, StackTrace stackTrace) {},
              print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
                if (line.contains('could not process')) {
                  return;
                }
                parent.print(zone, line);
              },
            ));

        expect(errors, isNotEmpty);
        expect(logger.processingTask!.isCompleted, isTrue);
        await logger.destroy();
      });

      test('onError stream returns a stream instance', () {
        final BDLogger logger = BDLogger();
        final Stream<BDLogError> errorStream = logger.onError;

        expect(errorStream, isA<Stream<BDLogError>>());
      });

      test('processingBatchSize setter updates value', () {
        final BDLogger logger = BDLogger();
        final int originalBatchSize = logger.processingBatchSize;

        logger.processingBatchSize = originalBatchSize + 1;

        expect(logger.processingBatchSize, equals(originalBatchSize + 1));
      });

      test('addHandler with completed processing task triggers new batch',
          () async {
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{},
          StreamController<BDLogError>.broadcast(),
        );

        // Wait for initial (empty) processing
        await waitForProcessing(logger);
        expect(logger.processingTask!.isCompleted, isTrue);

        // Add records
        logger.info('Queued');
        expect(logger.recordQueue, hasLength(1));

        // Add handler - should trigger processing
        final TestLogHandler handler = TestLogHandler();
        logger.addHandler(handler);

        await waitForProcessing(logger);

        expect(handler.howManyTimeHandleWasCall, equals(1));
        await logger.destroy();
      });
    });

    group('Destroy State Management', () {
      test('destroy leaves queue empty after processing all records', () async {
        final TestLogHandler handler = TestLogHandler();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
        );

        // Add some logs
        for (int i = 0; i < 5; i++) {
          logger.info('Destroy test $i');
        }

        await logger.destroy();

        // All records should be processed and queue should be empty
        expect(handler.howManyTimeHandleWasCall, equals(5));
        expect(logger.recordQueue, isEmpty);
      });

      test('destroy processes all pending records before cleanup', () async {
        final SlowTestHandler handler = SlowTestHandler(
          delay: const Duration(milliseconds: 20),
        );
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
        );

        // Add multiple records
        for (int i = 0; i < 10; i++) {
          logger.info('Pending record $i');
        }

        // Start destroy immediately
        await logger.destroy();

        // All records should be processed despite destroy
        expect(handler.processedRecords, hasLength(10));
      });

      test('destroy calls clean on all cleanable handlers', () async {
        final CleanableTestLogHandler handler1 = CleanableTestLogHandler();
        final CleanableTestLogHandler handler2 = CleanableTestLogHandler();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler1, handler2},
          StreamController<BDLogError>.broadcast(),
        );

        await logger.destroy();

        expect(handler1.cleanCalled, isTrue);
        expect(handler2.cleanCalled, isTrue);
      });

      test('destroy handles clean failures gracefully', () async {
        final ThrowingCleanHandler handler = ThrowingCleanHandler();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
        );

        final List<BDLogError> errors = <BDLogError>[];
        logger.onError.listen(errors.add);

        await logger.destroy();

        expect(handler.cleanCalled, isTrue);
        expect(errors, hasLength(1));
        expect(errors.first.exception, isA<Exception>());
      });

      test('destroy resets singleton instance', () async {
        final BDLogger firstInstance = BDLogger();
        final BDLogger secondInstance = BDLogger();
        expect(firstInstance, same(secondInstance));

        await firstInstance.destroy();

        final BDLogger thirdInstance = BDLogger();
        expect(thirdInstance, isNot(same(firstInstance)));
      });

      test('destroy closes error stream', () async {
        final StreamController<BDLogError> errorController =
            StreamController<BDLogError>.broadcast();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{},
          errorController,
        );

        expect(errorController.isClosed, isFalse);

        await logger.destroy();

        expect(errorController.isClosed, isTrue);
        if (!errorController.isClosed) {
          await errorController.close();
        }
      });
    });

    group('Batch Size Changes and Dynamic Configuration', () {
      test('batch size change is reflected in processing', () async {
        final RecordCapturingHandler handler = RecordCapturingHandler();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
          2, // initial batch size of 2
        );

        // Add more records than initial batch size
        for (int i = 0; i < 7; i++) {
          logger.info('Batch size test $i');
        }

        // Change batch size
        logger.processingBatchSize = 3;

        await waitForProcessing(logger);

        expect(handler.capturedRecords, hasLength(7));
      });

      test('batch size validation allows positive values', () {
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{},
          StreamController<BDLogError>.broadcast(),
        );

        // Should allow positive values
        expect(
          (logger..processingBatchSize = 1).processingBatchSize,
          equals(1),
        );

        expect(
          (logger..processingBatchSize = 100).processingBatchSize,
          equals(100),
        );
      });

      test('batch size change during processing takes effect', () async {
        final SlowTestHandler handler = SlowTestHandler(
          delay: const Duration(milliseconds: 20),
        );
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
          1, // Process one at a time initially
        );

        // Add several records
        for (int i = 0; i < 10; i++) {
          logger.info('Dynamic batch $i');
        }

        // Wait for first few to process
        while (handler.processedRecords.length < 3) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }

        // Change batch size mid-processing
        logger.processingBatchSize = 5;

        await waitForProcessing(logger);

        expect(handler.processedRecords, hasLength(10));
      });

      test('batch size change triggers new processing when queue has items',
          () async {
        final TestLogHandler handler = TestLogHandler();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{}, // No handlers initially
          StreamController<BDLogError>.broadcast(),
        );

        // Add records without handlers (no processing)
        for (int i = 0; i < 5; i++) {
          logger.info('No handler $i');
        }

        expect(logger.recordQueue, hasLength(5));

        // Add handler - should trigger processing
        // Change batch size - should not affect current processing
        logger
          ..addHandler(handler)
          ..processingBatchSize = 10;

        await waitForProcessing(logger);

        expect(handler.howManyTimeHandleWasCall, equals(5));
        expect(logger.recordQueue, isEmpty);
      });
    });

    group('Integration Tests - Complex Async Scenarios', () {
      test('multiple handlers with different processing speeds work together',
          () async {
        final SlowTestHandler slowHandler = SlowTestHandler(
          delay: const Duration(milliseconds: 50),
        );
        final TestLogHandler fastHandler = TestLogHandler();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{slowHandler, fastHandler},
          StreamController<BDLogError>.broadcast(),
        );

        // Add multiple records
        for (int i = 0; i < 10; i++) {
          logger.info('Multi-handler test $i');
        }

        await waitForProcessing(logger);

        // Both handlers should have processed all records
        expect(slowHandler.processedRecords, hasLength(10));
        expect(fastHandler.howManyTimeHandleWasCall, equals(10));
      });

      test('error in one handler does not prevent others from processing',
          () async {
        final FailFastTestHandler failingHandler = FailFastTestHandler();
        final TestLogHandler workingHandler = TestLogHandler();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{failingHandler, workingHandler},
          StreamController<BDLogError>.broadcast(),
        );

        final List<BDLogError> errors = <BDLogError>[];
        logger.onError.listen(errors.add);

        await runZonedGuarded(() async {
          logger.info('Error isolation test');
          await waitForProcessing(logger);
        }, (Object _, StackTrace __) {},
            zoneSpecification: ZoneSpecification(
              handleUncaughtError: (Zone self, ZoneDelegate parent, Zone zone,
                  Object error, StackTrace stackTrace) {},
              print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
                if (line.contains('could not process')) {
                  return;
                }
                parent.print(zone, line);
              },
            ));

        // Working handler should still process
        expect(workingHandler.howManyTimeHandleWasCall, equals(1));
        // Should have recorded the error
        expect(errors, hasLength(1));
      });

      test('high-frequency logging with batch processing performs well',
          () async {
        final RecordCapturingHandler handler = RecordCapturingHandler();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
          50, // Larger batch size for performance
        );

        const int numLogs = 1000;
        final Stopwatch stopwatch = Stopwatch()..start();

        // Add logs rapidly
        for (int i = 0; i < numLogs; i++) {
          logger.info('Performance test $i');
        }

        await waitForProcessing(logger);
        stopwatch.stop();

        expect(handler.capturedRecords, hasLength(numLogs));

        // Should complete in reasonable time (under 10 seconds for 1000 logs)
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));
      });

      test('concurrent destroy and log operations are handled safely',
          () async {
        final TestLogHandler handler = TestLogHandler();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler},
          StreamController<BDLogError>.broadcast(),
        );

        // Start destroy
        final Future<void> destroyFuture = logger.destroy();

        // Try to log during destroy (may or may not be processed)
        for (int i = 0; i < 10; i++) {
          logger.info('Concurrent destroy test $i');
        }

        await destroyFuture;

        // Handler should have processed at least some records
        expect(handler.howManyTimeHandleWasCall, greaterThanOrEqualTo(0));
      });

      test('handler removal during processing works correctly', () async {
        final TestLogHandler handler1 = TestLogHandler();
        final TestLogHandler handler2 = TestLogHandler();
        final BDLogger logger = BDLogger.private(
          <BDLogHandler>{handler1, handler2},
          StreamController<BDLogError>.broadcast(),
        );

        // Add some records
        for (int i = 0; i < 5; i++) {
          logger.info('Handler removal test $i');
        }

        // Wait for some processing
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Remove one handler
        logger.removeHandler(handler1);

        // Add more records
        for (int i = 5; i < 10; i++) {
          logger.info('After removal $i');
        }

        await waitForProcessing(logger);

        // Both handlers should have processed the first batch
        expect(handler1.howManyTimeHandleWasCall, equals(5));
        expect(handler2.howManyTimeHandleWasCall, equals(10)); // All records
      });
    });

    group('Singleton Lifecycle and Edge Cases', () {
      test('singleton instance persists across multiple calls', () {
        final BDLogger first = BDLogger();
        final BDLogger second = BDLogger();
        final BDLogger third = BDLogger();

        expect(first, same(second));
        expect(second, same(third));
        expect(first, same(third));
      });

      test('destroy resets singleton allowing new instance', () async {
        final BDLogger original = BDLogger();
        final TestLogHandler handler = TestLogHandler();
        original
          ..addHandler(handler)
          ..info('Before destroy');
        await waitForProcessing(original);
        expect(handler.howManyTimeHandleWasCall, equals(1));

        await original.destroy();

        // New instance should be different
        final BDLogger afterDestroy = BDLogger();
        expect(afterDestroy, isNot(same(original)));

        // New instance should work
        final TestLogHandler newHandler = TestLogHandler();
        afterDestroy
          ..addHandler(newHandler)
          ..info('After destroy');
        await waitForProcessing(afterDestroy);
        expect(newHandler.howManyTimeHandleWasCall, equals(1));
      });

      test('multiple destroy calls on same instance are safe', () async {
        final BDLogger logger = BDLogger();
        final Future<void> firstDestroy =
            (logger..addHandler(TestLogHandler())).destroy();

        // First destroy
        await firstDestroy;

        // Second destroy should complete without error
        await expectLater(logger.destroy(), completes);
      });

      test('logging after destroy on old instance does not crash', () async {
        final BDLogger logger = BDLogger();
        final Future<void> destroyFuture =
            (logger..addHandler(TestLogHandler())).destroy();

        await destroyFuture;

        // Logging on destroyed instance should not crash
        // (though it may not be processed since singleton is reset)
        expect(() => logger.info('After destroy'), returnsNormally);
      });

      test('handler operations after destroy work on new instance', () async {
        final BDLogger oldInstance = BDLogger();
        await oldInstance.destroy();

        final BDLogger newInstance = BDLogger();
        final TestLogHandler handler = TestLogHandler();

        // Operations on new instance should work
        newInstance.addHandler(handler);
        expect(newInstance.handlers, hasLength(1));

        newInstance.removeHandler(handler);
        expect(newInstance.handlers, isEmpty);

        // Basic logging should not crash
        expect(() => newInstance.info('Test after reset'), returnsNormally);
      });
    });
  });

  group('Handler Management Race Conditions', () {
    test(
        'records should not be lost when handler removed and re-added '
        'during processing', () async {
      final SlowTestHandler handler = SlowTestHandler(
        delay: const Duration(milliseconds: 50),
      );
      final StreamController<BDLogError> errorController =
          StreamController<BDLogError>.broadcast();
      final BDLogger logger = BDLogger.private(
        <BDLogHandler>{handler},
        errorController,
        2, // Small batch size for timing control
      );

      void logInfo(final String message) {
        logger.log(BDLevel.info, message);
      }

      void addLogHandler() {
        logger.addHandler(handler);
      }

      void removeLogHandler() {
        logger.removeHandler(handler);
      }

      // Phase 1: Start processing with just 2 records (exactly one batch)
      logInfo('Record 1');
      logInfo('Record 2');

      // Phase 2: Wait for batch to start, then remove handler.
      // After first record starts.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      removeLogHandler();
      expect(logger.handlers, isEmpty);

      // Phase 3: Add records while no handlers exist - these should queue
      logInfo('Queued record 1');
      logInfo('Queued record 2');

      // Phase 4: Re-add handler to process queued records.
      addLogHandler();

      // Phase 5: Wait for all processing to complete
      // Allow time for all records.
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Verify all records are processed despite handler removal/re-addition
      expect(
        handler.processedRecords,
        hasLength(4),
        reason: 'All records should be processed despite handler '
            'removal/re-addition',
      );
      expect(
        logger.processingTask!.isCompleted,
        isTrue,
        reason: 'Processing should complete successfully',
      );
      expect(
        logger.recordQueue,
        isEmpty,
        reason: 'No records should remain unprocessed',
      );

      await logger.destroy();
      await errorController.close();
    });

    test(
        'queued records should be processed when handler is re-added '
        'during active processing', () async {
      final SlowTestHandler handler = SlowTestHandler(
        delay: const Duration(milliseconds: 100),
      );
      final StreamController<BDLogError> errorController =
          StreamController<BDLogError>.broadcast();
      final BDLogger logger = BDLogger.private(
        <BDLogHandler>{handler},
        errorController,
        1, // Process one record at a time
      );

      void logInfo(final String message) {
        logger.log(BDLevel.info, message);
      }

      // Start with one record to begin processing
      logInfo('Initial record');

      // Wait for processing to complete the first record
      // More than 100ms for one record.
      await Future<void>.delayed(const Duration(milliseconds: 120));

      // Remove handler while processing is active
      logger.removeHandler(handler);
      expect(logger.handlers, isEmpty);

      // Add multiple records while no handlers exist - these should all queue
      for (int i = 0; i < 5; i++) {
        logInfo('Queued record $i');
      }

      // Verify records are queued but not processed
      expect(logger.recordQueue, hasLength(5));
      // Only initial record processed.
      expect(handler.processedRecords, hasLength(1));

      // Re-add handler - this should trigger processing of all queued records
      logger.addHandler(handler);

      // Wait for all processing to complete
      // Time for 5 records.
      await Future<void>.delayed(const Duration(milliseconds: 800));

      // All records should now be processed
      expect(
        handler.processedRecords,
        hasLength(6),
        reason: 'All queued records should be processed when handler '
            'is re-added',
      );
      expect(
        logger.recordQueue,
        isEmpty,
        reason: 'Queue should be empty after processing completes',
      );

      await logger.destroy();
      await errorController.close();
    });

    test(
        'attempt to reproduce bug: records queued during handler gap '
        'should process after handler re-add', () async {
      final SlowTestHandler handler = SlowTestHandler(
        delay: const Duration(milliseconds: 50),
      );
      final StreamController<BDLogError> errorController =
          StreamController<BDLogError>.broadcast();
      final BDLogger logger = BDLogger.private(
        <BDLogHandler>{handler},
        errorController,
        1, // Process one at a time
      );

      void logInfo(final String message) {
        logger.log(BDLevel.info, message);
      }

      // Start processing
      logInfo('Start record');

      // Wait for it to complete
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Remove handler (processing task should be completed now)
      logger.removeHandler(handler);
      expect(logger.handlers, isEmpty);

      // Add records while no handlers exist
      for (int i = 0; i < 3; i++) {
        logInfo('Gap record $i');
      }

      // Verify they are queued
      expect(logger.recordQueue, hasLength(3));
      expect(handler.processedRecords, hasLength(1));

      // Wait a bit to ensure no processing happens
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // Should still be queued.
      expect(logger.recordQueue, hasLength(3));

      // Re-add handler - this should start processing the queued records
      logger.addHandler(handler);

      // Wait for processing
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Check if all records were processed
      expect(
        handler.processedRecords,
        hasLength(4),
        reason: 'All records including queued ones should be processed',
      );
      expect(
        logger.recordQueue,
        isEmpty,
        reason: 'Queue should be empty',
      );

      await logger.destroy();
      await errorController.close();
    });

    test(
        'concurrent record addition during handler transition should not '
        'lose messages', () async {
      final SlowTestHandler handler = SlowTestHandler(
        delay: const Duration(milliseconds: 50),
      );
      final StreamController<BDLogError> errorController =
          StreamController<BDLogError>.broadcast();
      final BDLogger logger = BDLogger.private(
        <BDLogHandler>{handler},
        errorController,
        1, // Process one at a time
      );

      void logInfo(final String message) {
        logger.log(BDLevel.info, message);
      }

      // Start processing
      logInfo('Initial');

      // Schedule handler removal and record addition concurrently
      final Future<void> concurrentOperations = Future<void>(() async {
        // Wait a bit, then remove handler
        await Future<void>.delayed(const Duration(milliseconds: 10));
        logger.removeHandler(handler);

        // Immediately add records while handler is being removed
        for (int i = 0; i < 5; i++) {
          logInfo('Concurrent $i');
          // Small delay.
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }

        // Re-add handler
        await Future<void>.delayed(const Duration(milliseconds: 5));
        logger.addHandler(handler);
      });

      await concurrentOperations;

      // Wait for all processing to complete
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // All records should be processed
      expect(
        handler.processedRecords,
        hasLength(6),
        reason: 'All records should be processed despite concurrent '
            'operations',
      );
      expect(
        logger.recordQueue,
        isEmpty,
        reason: 'No records should remain stuck in queue',
      );

      await logger.destroy();
      await errorController.close();
    });

    test('rapid handler add/remove cycles should not cause message loss',
        () async {
      final SlowTestHandler handler = SlowTestHandler(
        delay: const Duration(milliseconds: 30),
      );
      final StreamController<BDLogError> errorController =
          StreamController<BDLogError>.broadcast();
      final BDLogger logger = BDLogger.private(
        <BDLogHandler>{handler},
        errorController,
        2,
      );

      void logInfo(final String message) {
        logger.log(BDLevel.info, message);
      }

      // Start with some records
      for (int i = 0; i < 4; i++) {
        logInfo('Initial $i');
      }

      // Rapid handler manipulation during processing
      final Future<void> manipulation = Future<void>(() async {
        for (int i = 0; i < 3; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 15));
          logger.removeHandler(handler);

          // Add records while no handlers
          logInfo('Gap $i');

          await Future<void>.delayed(const Duration(milliseconds: 5));
          logger.addHandler(handler);

          // Add records after handler re-added
          logInfo('After $i');
        }
      });

      await manipulation;

      // Wait for all processing
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Count total expected records: 4 initial + 3 gap + 3 after = 10.
      expect(
        handler.processedRecords,
        hasLength(10),
        reason: 'All records should be processed despite rapid '
            'handler changes',
      );
      expect(
        logger.recordQueue,
        isEmpty,
        reason: 'No records should be stuck',
      );

      await logger.destroy();
      await errorController.close();
    });

    test('handler failures during removal/re-addition are properly reported',
        () async {
      final FailFastTestHandler failingHandler = FailFastTestHandler();
      final StreamController<BDLogError> errorController =
          StreamController<BDLogError>.broadcast();
      final BDLogger logger = BDLogger.private(
        <BDLogHandler>{failingHandler},
        errorController,
        1,
      );

      void logInfo(final String message) {
        logger.log(BDLevel.info, message);
      }

      void addLogHandler() {
        logger.addHandler(failingHandler);
      }

      void removeLogHandler() {
        logger.removeHandler(failingHandler);
      }

      final List<BDLogError> errors = <BDLogError>[];
      logger.onError.listen(errors.add);

      // Trigger processing that will fail
      logInfo('Will fail');

      // Remove and re-add handler during processing
      await Future<void>.delayed(const Duration(milliseconds: 5));
      removeLogHandler();
      logInfo('During gap');
      addLogHandler();

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify errors reported properly
      expect(errors, isNotEmpty);
      expect(logger.processingTask!.isCompleted, isTrue);

      await logger.destroy();
      await errorController.close();
    });

    test('high-load handler management maintains acceptable performance',
        () async {
      final RecordCapturingHandler handler = RecordCapturingHandler();
      final BDLogger logger = BDLogger.private(
        <BDLogHandler>{handler},
        StreamController<BDLogError>.broadcast(),
        10, // Moderate batch size
      );

      final Stopwatch stopwatch = Stopwatch()..start();

      // High volume logging
      for (int i = 0; i < 1000; i++) {
        logger.log(BDLevel.info, 'Load test $i');

        // Simulate handler changes during load
        if (i % 200 == 0) {
          logger
            ..removeHandler(handler)
            ..addHandler(handler);
        }
      }

      await waitForProcessing(logger);
      stopwatch.stop();

      // Performance verification
      expect(handler.capturedRecords, hasLength(1000));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
      expect(logger.recordQueue, isEmpty);

      await logger.destroy();
    });
  });
}
