import 'dart:async';

import 'package:bdlogging/bdlogging.dart';
import 'package:test/test.dart';

import 'test_log_handler.dart';

void main() {
  tearDown(
    // destroy the singleton of BDLogging after each test.
    // so that a new instance is created on each test.
    BDLogger().destroy,
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
      final StreamController<BDLogRecord> streamController =
          StreamController<BDLogRecord>.broadcast();

      final TestLogHandler firstHandler = TestLogHandler();
      final TestLogHandler secondHandler = TestLogHandler();

      final BDLogger logger = BDLogger.private(
        'TestLogger',
        <BDLogHandler>[firstHandler, secondHandler],
        streamController,
      );

      expect(firstHandler.howManyTimeHandleWasCall, equals(0));
      expect(secondHandler.howManyTimeHandleWasCall, equals(0));

      logger.info(
        'he he he man the test should pass :)',
      );

      await streamController.close();

      expect(
        firstHandler.howManyTimeHandleWasCall,
        equals(1),
      );

      expect(
        secondHandler.howManyTimeHandleWasCall,
        equals(1),
      );
    },
  );
}
