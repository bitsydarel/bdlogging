import 'dart:async';
import 'dart:io';

import 'package:bdlogging/bdlogging.dart';

void main() {
  final BDLogger logger = BDLogger()
    ..addHandler(
      ConsoleLogHandler(
        supportedLevels: BDLevel.values
            .where((BDLevel level) => level != BDLevel.error)
            .toList(),
      ),
    )
    ..addHandler(
      FileLogHandler(
        logNamePrefix: 'example',
        maxLogSizeInMb: 5,
        maxFilesCount: 5,
        logFileDirectory: Directory.current,
        supportedLevels: <BDLevel>[BDLevel.error],
      ),
    )
    ..debug('Initialized logger');

  Timer(const Duration(seconds: 1), () {
    logger.info('1 seconds timer completed');
  });

  logger.warning('Starting some time consuming task');

  for (int i = 0; i < 1000; i++) {
    logger.warning('Consuming task $i');
  }

  logger.warning('Time consuming task completed');

  runZonedGuarded<void>(
    () {
      for (int i = 0; i <= 4; i++) {
        if (i == 4) {
          throw const FormatException('we reached 4');
        }
        logger.info('runZoned for loop i == $i');
      }
    },
    (Object error, StackTrace stackTrace) {
      logger.error('runZoned on error', error, stackTrace: stackTrace);
    },
  );

  for (int i = 0; i <= 10000000; i++) {
    logger.log(BDLevel.error, 'Iteration number: $i');
  }
}
