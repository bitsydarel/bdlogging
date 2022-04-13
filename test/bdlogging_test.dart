import 'dart:async';

import 'package:bdlogging/bdlogging.dart';
import 'package:bdlogging/src/bd_log_handler.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_log_handler.dart';

void main() {
  tearDown(
    // destroy the singleton of BDLogging after each test.
    // so that a new instance is created on each test.
    BDLogging().destroy,
  );

  test(
    'only one instance of a logger can exist until destroy is call',
    () {
      final BDLogging firstCallLogger = BDLogging();
      final BDLogging secondCallLogger = BDLogging();

      expect(firstCallLogger, same(secondCallLogger));

      firstCallLogger.destroy();

      final BDLogging newLogger = BDLogging();

      expect(firstCallLogger, isNot(newLogger));
      expect(secondCallLogger, isNot(newLogger));
    },
  );

  test(
    'should add a new handler when add handler is called',
    () {
      final BDLogging logger = BDLogging();

      expect(logger.handlers, hasLength(0));

      final TestLogHandler logHandler = TestLogHandler();

      logger.addHandler(logHandler);

      expect(logger.handlers, hasLength(1));
    },
  );

  test(
    'Should remove handler when remove handler is called',
    () {
      final BDLogging logger = BDLogging();
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
      final BDLogging logger = BDLogging();
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

      final BDLogging logger = BDLogging.private(
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
