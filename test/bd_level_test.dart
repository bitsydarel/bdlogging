import 'package:bdlogging/src/bd_level.dart';
import 'package:test/test.dart';

void main() {
  group('BDLevel', () {
    test('exposes labels and importance values', () {
      expect(BDLevel.debug.label, equals('DEBUG'));
      expect(BDLevel.info.label, equals('INFO'));
      expect(BDLevel.warning.label, equals('WARNING'));
      expect(BDLevel.success.label, equals('SUCCESS'));
      expect(BDLevel.error.label, equals('ERROR'));

      expect(BDLevel.debug.importance, equals(3));
      expect(BDLevel.info.importance, equals(4));
      expect(BDLevel.warning.importance, equals(5));
      expect(BDLevel.success.importance, equals(6));
      expect(BDLevel.error.importance, equals(7));
    });

    test('comparison operators and compareTo work', () {
      expect(BDLevel.debug < BDLevel.info, isTrue);
      expect(BDLevel.warning > BDLevel.info, isTrue);
      expect(BDLevel.success >= BDLevel.success, isTrue);
      expect(BDLevel.error >= BDLevel.success, isTrue);
      expect(BDLevel.info <= BDLevel.warning, isTrue);
      expect(BDLevel.debug.compareTo(BDLevel.error), lessThan(0));
    });

    test('toString includes label and importance', () {
      final String description = BDLevel.error.toString();

      expect(description, contains('label: ERROR'));
      expect(description, contains('importance: 7'));
    });
  });
}
