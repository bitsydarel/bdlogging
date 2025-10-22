import 'package:bdlogging/src/bd_log_record.dart';

/// [BDLogRecord] Formatter.
abstract class BDLogFormatter {
  /// Const constructor for [BDLogFormatter].
  const BDLogFormatter();

  /// Converts the formatter configuration to a JSON-serializable map.
  Map<String, dynamic> toJson();

  /// Creates a [BDLogFormatter] instance from a JSON map.
  BDLogFormatter fromJson(Map<String, dynamic> json);

  /// Format the [record] to a [String] representation.
  String format(final BDLogRecord record);
}
