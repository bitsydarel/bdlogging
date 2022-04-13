import 'package:bdlogging/src/bd_log_handler.dart';

/// A [BDLogHandler] that contains resources that should be cleared.
abstract class BDCleanableLogHandler extends BDLogHandler {
  /// Create [BDCleanableLogHandler].
  const BDCleanableLogHandler();

  /// Clean resources contained within this [BDLogHandler].
  Future<void> clean();
}
