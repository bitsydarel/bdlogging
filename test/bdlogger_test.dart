import 'dart:async';

import 'package:bdlogging/bdlogging.dart';
import 'package:test/test.dart';

import 'test_log_handler.dart';

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

        while (logger.recordQueue.isNotEmpty) {
          await Future<void>.delayed(BDLogger.defaultProcessingInterval);
        }

        expect(firstHandler.howManyTimeHandleWasCall, equals(1));

        expect(secondHandler.howManyTimeHandleWasCall, equals(1));
      },
    );

    test(
      'processingInterval should control the frequency of log processing',
      () async {
        final BDLogger logger = BDLogger();
        final TestLogHandler handler = TestLogHandler();
        logger
          ..addHandler(handler)
          ..processingInterval = const Duration(milliseconds: 500)
          ..debug('Debug message');

        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(handler.howManyTimeHandleWasCall, equals(0));

        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(handler.howManyTimeHandleWasCall, equals(1));

        logger.destroy();
      },
    );

    test(
      'processingBatchSize should control '
      'the number of logs processed at a time',
      () async {
        final BDLogger logger = BDLogger();
        final TestLogHandler handler = TestLogHandler();

        logger
          ..addHandler(handler)
          ..processingBatchSize = 2
          ..debug('Debug message 1')
          ..debug('Debug message 2')
          ..debug('Debug message 3');

        await Future<void>.delayed(logger.processingInterval);
        expect(handler.howManyTimeHandleWasCall, equals(2));

        await Future<void>.delayed(logger.processingInterval);
        expect(handler.howManyTimeHandleWasCall, equals(3));

        logger.destroy();
      },
    );

    test(
      'log processing should stop after destroy is called',
      () async {
        final BDLogger logger = BDLogger();
        final TestLogHandler handler = TestLogHandler();
        logger
          ..addHandler(handler)
          ..debug('Debug message 1');

        await logger.destroy();
        logger.debug('Debug message 2');

        await Future<void>.delayed(logger.processingInterval);
        expect(handler.howManyTimeHandleWasCall, equals(1));

        logger.destroy();
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

        // Wait for all logs to be processed
        final Completer<void> completer = Completer<void>();
        Timer.periodic(logger.processingInterval, (Timer timer) {
          if (logger.recordQueue.isEmpty) {
            timer.cancel();
            completer.complete();
          }
        });

        await completer.future;
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

        logger.destroy();
      },
    );
  });
}
