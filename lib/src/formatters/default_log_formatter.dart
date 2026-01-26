import 'package:bdlogging/src/bd_log_formatter.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:intl/intl.dart';

/// Default implementation of a [BDLogFormatter].
///
/// Format [BDLogRecord] to look like this:
///
/// {time}{level}{message}{error}{stacktrace}
class DefaultLogFormatter extends BDLogFormatter {
  /// Create [DefaultLogFormatter].
  const DefaultLogFormatter();

  /// Cached DateFormat instance for performance.
  static final DateFormat _formatter = DateFormat('dd-MM-yyyy H:m:s');

  @override
  String format(final BDLogRecord record) {
    final String time = _formatter.format(record.time);

    final StringBuffer buffer = StringBuffer()
      ..writeln()
      ..write(time)
      ..write(' ${record.level.label}: ${record.isFatal ? 'FATAL ' : ''}')
      ..write('${record.message} ');

    if (record.error != null) {
      buffer.writeln(record.error.toString());
    }
    if (record.stackTrace != null) {
      buffer
        ..writeln()
        ..writeln(record.stackTrace.toString());
    }

    return buffer.toString();
  }
}
