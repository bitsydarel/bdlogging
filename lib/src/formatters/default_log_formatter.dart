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

  @override
  String format(final BDLogRecord record) {
    final DateFormat formatter = DateFormat('dd-MM-yyyy H:m:s');
    final String time = formatter.format(record.time);

    final StringBuffer buffer = StringBuffer()
      ..writeln()
      ..write(time)
      ..write(' ${record.level.name}: ')
      ..write('${record.message} ');

    if (record.error != null) {
      buffer.write(record.error.toString());
    }
    if (record.stackTrace != null) {
      buffer..writeln()..writeln(record.stackTrace.toString());
    }

    return buffer.toString();
  }
}
