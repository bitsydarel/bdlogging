import 'dart:convert';
import 'dart:io';

import 'package:bdlogging/src/security/sensitive_data_encryptor.dart';
import 'package:test/test.dart';

int _readEnvInt(String name, int fallback) {
  return int.tryParse(Platform.environment[name] ?? '') ?? fallback;
}

void main() {
  group('AesGcmSensitiveDataEncryptor', () {
    test('encrypts and decrypts values', () async {
      final SensitiveDataEncryptor encryptor =
          AesGcmSensitiveDataEncryptor('password-123');

      final String encrypted = await encryptor.encrypt('secret-value');
      final String decrypted = await encryptor.decrypt(encrypted);

      expect(decrypted, equals('secret-value'));
      expect(encrypted, isNot(equals('secret-value')));
    });

    test('returns empty string when input is empty', () async {
      final SensitiveDataEncryptor encryptor =
          AesGcmSensitiveDataEncryptor('password-123');

      expect(await encryptor.encrypt(''), isEmpty);
      expect(await encryptor.decrypt(''), isEmpty);
    });

    test('produces distinct ciphertexts for different values', () async {
      final SensitiveDataEncryptor encryptor =
          AesGcmSensitiveDataEncryptor('password-123');

      final String encryptedA = await encryptor.encrypt('secret-a');
      final String encryptedB = await encryptor.encrypt('secret-b');

      expect(encryptedA, isNot(equals(encryptedB)));
    });

    test('throws when ciphertext is tampered', () async {
      final SensitiveDataEncryptor encryptor =
          AesGcmSensitiveDataEncryptor('password-123');

      final String encrypted = await encryptor.encrypt('secret-value');
      final List<int> bytes = base64Decode(encrypted);
      bytes[bytes.length - 1] = bytes[bytes.length - 1] ^ 0xFF;
      final String tampered = base64Encode(bytes);

      expect(() => encryptor.decrypt(tampered), throwsA(isA<Object>()));
    });

    test('throws when password is incorrect', () async {
      final SensitiveDataEncryptor encryptor =
          AesGcmSensitiveDataEncryptor('password-123');
      final SensitiveDataEncryptor wrongPassword =
          AesGcmSensitiveDataEncryptor('wrong-password');

      final String encrypted = await encryptor.encrypt('secret-value');

      expect(() => wrongPassword.decrypt(encrypted), throwsA(isA<Object>()));
    });

    test('handles high volume within time budget', () async {
      final SensitiveDataEncryptor encryptor =
          AesGcmSensitiveDataEncryptor('password-123');
      final int count = _readEnvInt('BDLOG_ENCRYPT_LOAD', 100);
      final int budgetSeconds = _readEnvInt('BDLOG_ENCRYPT_BUDGET', 12);
      final Stopwatch stopwatch = Stopwatch()..start();

      for (int i = 0; i < count; i++) {
        final String encrypted = await encryptor.encrypt('value-$i');
        final String decrypted = await encryptor.decrypt(encrypted);
        expect(decrypted, equals('value-$i'));
      }

      stopwatch.stop();
      expect(stopwatch.elapsed.inSeconds, lessThan(budgetSeconds));
    },
        timeout: const Timeout(
          Duration(seconds: 25),
        ));
  });
}
