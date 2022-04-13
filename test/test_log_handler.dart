import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_handler.dart';
import 'package:bdlogging/src/bd_log_record.dart';

class TestLogHandler extends BDLogHandler {
  int howManyTimeHandleWasCall = 0;

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    howManyTimeHandleWasCall++;
  }

  @override
  bool supportLevel(BDLevel level) => true;
}

class FailFastTestHandler extends BDLogHandler {
  bool shouldAcceptEveryRecord = true;
  int howManyTimeHandleWasCall = 0;
  void Function()? crashFunction;

  FailFastTestHandler({void Function()? crash})
      : crashFunction = crash ?? _crash;

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    howManyTimeHandleWasCall++;
    crashFunction?.call();
  }

  @override
  bool supportLevel(BDLevel level) => shouldAcceptEveryRecord;

  static void _crash() {
    throw Exception('failed to process');
  }
}
