import 'package:bdlogging/bdlogging.dart';

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

class CleanableTestLogHandler extends BDCleanableLogHandler {
  bool cleanCalled = false;
  int howManyTimeHandleWasCall = 0;

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    howManyTimeHandleWasCall++;
  }

  @override
  Future<void> clean() async {
    cleanCalled = true;
  }

  @override
  bool supportLevel(BDLevel level) => true;
}
