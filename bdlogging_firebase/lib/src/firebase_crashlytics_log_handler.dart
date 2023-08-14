import 'dart:collection';

import 'package:bdlogging/bdlogging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// A implementation of [BDLogHandler] that log [BDLogRecord] to firebase.
class FirebaseCrashlyticsLogHandler implements BDLogHandler {
  /// Create a [FirebaseCrashlyticsLogHandler].
  FirebaseCrashlyticsLogHandler({
    required FirebaseCrashlytics crashlytics,
    required List<BDLevel> supportedLevels,
    BDLogFormatter logFormatter = const DefaultLogFormatter(),
  })  : _crashlytics = crashlytics,
        _supportedLevels = UnmodifiableListView<BDLevel>(supportedLevels),
        _formatter = logFormatter;

  final FirebaseCrashlytics _crashlytics;
  final List<BDLevel> _supportedLevels;
  final BDLogFormatter _formatter;

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    final Object? error = record.error;

    if (error != null) {
      return _crashlytics.recordError(
        record,
        record.stackTrace,
        reason: record.message,
        fatal: record.isFatal,
      );
    } else {
      final String recordFormatted = _formatter.format(record);

      return _crashlytics.log(recordFormatted);
    }
  }

  @override
  bool supportLevel(BDLevel level) => _supportedLevels.contains(level);
}
