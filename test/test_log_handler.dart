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

/// A handler that simulates slow processing with configurable delay.
class SlowTestHandler extends BDLogHandler {
  SlowTestHandler({required this.delay});
  final Duration delay;
  final List<BDLogRecord> processedRecords = <BDLogRecord>[];

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    await Future<void>.delayed(delay);
    processedRecords.add(record);
  }

  @override
  bool supportLevel(BDLevel level) => true;
}

/// A handler that attempts to log during handleRecord.
/// Used to test _isDestroying flag to prevent infinite loops.
class LoggingHandler extends BDLogHandler {
  LoggingHandler(this._logger);
  final BDLogger Function() _logger;
  int callCount = 0;

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    callCount++;
    // This would cause infinite loop without _isDestroying flag
    _logger().info('Logging from handler: ${record.message}');
  }

  @override
  bool supportLevel(BDLevel level) => true;
}

/// A handler that captures all records for verification.
class RecordCapturingHandler extends BDLogHandler {
  final List<BDLogRecord> capturedRecords = <BDLogRecord>[];

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    capturedRecords.add(record);
  }

  @override
  bool supportLevel(BDLevel level) => true;
}

/// A handler that only supports specific levels.
class LevelFilteringHandler extends BDLogHandler {
  LevelFilteringHandler(this.supportedLevels);
  final Set<BDLevel> supportedLevels;
  final List<BDLogRecord> capturedRecords = <BDLogRecord>[];

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    capturedRecords.add(record);
  }

  @override
  bool supportLevel(BDLevel level) => supportedLevels.contains(level);
}

/// A cleanable handler that throws on clean.
class ThrowingCleanHandler extends BDCleanableLogHandler {
  int handleCount = 0;
  bool cleanCalled = false;
  final Exception errorToThrow;

  ThrowingCleanHandler([Exception? errorToThrow])
      : errorToThrow = errorToThrow ?? Exception('Clean failed');

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    handleCount++;
  }

  @override
  Future<void> clean() async {
    cleanCalled = true;
    throw errorToThrow;
  }

  @override
  bool supportLevel(BDLevel level) => true;
}

/// A handler that tracks call order across multiple handlers.
class OrderTrackingHandler extends BDLogHandler {
  OrderTrackingHandler(this.id, this.callOrder);
  final String id;
  final List<String> callOrder;
  int handleCount = 0;

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    handleCount++;
    callOrder.add('$id:${record.message}');
  }

  @override
  bool supportLevel(BDLevel level) => true;
}

/// A handler that can be configured to fail after N calls.
class FailAfterNHandler extends BDLogHandler {
  FailAfterNHandler(this.failAfter);
  final int failAfter;
  int handleCount = 0;
  final List<BDLogRecord> capturedRecords = <BDLogRecord>[];

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    handleCount++;
    capturedRecords.add(record);
    if (handleCount > failAfter) {
      throw Exception('Intentional failure after $failAfter calls');
    }
  }

  @override
  bool supportLevel(BDLevel level) => true;
}

/// A handler that throws synchronously (not async).
class SyncThrowingHandler extends BDLogHandler {
  int handleCount = 0;

  @override
  Future<void> handleRecord(BDLogRecord record) {
    handleCount++;
    throw StateError('Sync error in handler');
  }

  @override
  bool supportLevel(BDLevel level) => true;
}

/// A handler that throws an Error (not Exception).
class ErrorThrowingHandler extends BDLogHandler {
  int handleCount = 0;

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    handleCount++;
    throw ArgumentError('Error in handler');
  }

  @override
  bool supportLevel(BDLevel level) => true;
}
