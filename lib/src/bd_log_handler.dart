import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_record.dart';

/// [BDLogHandler] handler.
///
/// It handles [BDLogRecord] messages.
abstract class BDLogHandler {
  /// Create a new instance of [BDLogHandler].
  const BDLogHandler();

  /// Allow the [BDLogHandler] to specify
  /// which [BDLevel] of [BDLogRecord] he can handle.
  ///
  /// return [bool] true if the [BDLevel] is supported.
  bool supportLevel(final BDLevel level);

  /// Handle the [BDLogRecord].
  Future<void> handleRecord(final BDLogRecord record);
}
