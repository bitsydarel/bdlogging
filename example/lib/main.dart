import 'dart:async';
import 'dart:io';

import 'package:bdlogging/bdlogging.dart';
import 'package:example/encrypted_log_formatter.dart';

void main() {
  final BDLogger logger = BDLogger()
    ..addHandler(
      IsolateFileLogHandler(
        Directory.current,
        logNamePrefix: 'ex',
        logFormatter: EncryptedLogFormatter(Person("Sam")),
        supportedLevels: BDLevel.values,
      ),
    )
    ..debug('Initialized logger');

  Timer(const Duration(seconds: 1), () {
    logger.info('1 seconds timer completed');
  });

  for (int i = 0; i <= 1000; i++) {
    logger.log(BDLevel.error, 'Iteration number: $i');
  }
}
