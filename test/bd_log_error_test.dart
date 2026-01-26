import 'package:bdlogging/src/bd_log_error.dart';
import 'package:test/test.dart';

void main() {
  group('BDLogError', () {
    test('can be created with const', () {
      const StackTrace emptyTrace = StackTrace.empty;
      const String error = 'Test error';

      const BDLogError logError = BDLogError(error, emptyTrace);

      expect(logError.exception, equals(error));
      expect(logError.stackTrace, equals(emptyTrace));
    });

    test('stores exception and stackTrace correctly', () {
      final Exception exception = Exception('Test exception');
      final StackTrace stackTrace = StackTrace.current;

      final BDLogError logError = BDLogError(exception, stackTrace);

      expect(logError.exception, equals(exception));
      expect(logError.stackTrace, equals(stackTrace));
    });
  });
}
