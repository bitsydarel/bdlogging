// Run with: dart run test/security/browser_decryption_compatibility_test.dart
// This generates test values to verify the HTML decryption tool
// works correctly.

import 'package:bdlogging/src/security/sensitive_data_encryptor.dart';
import 'package:test/test.dart';

void main() {
  test('prints sample values for the HTML decrypt tool', () async {
    const String password = 'test-password-123';
    const String testValue = 'Hello, QA Team!';

    final SensitiveDataEncryptor encryptor =
        AesGcmSensitiveDataEncryptor(password);

    final String encrypted = await encryptor.encrypt(testValue);

    // ignore: avoid_print
    print('=== AES-GCM Encryption Test ===\n');
    // ignore: avoid_print
    print('Original value: $testValue');
    // ignore: avoid_print
    print('Password: $password');
    // ignore: avoid_print
    print('Encrypted (base64): $encrypted');
    // ignore: avoid_print
    print('\n--- Verification ---');

    final String decrypted = await encryptor.decrypt(encrypted);
    // ignore: avoid_print
    print('Decrypted: $decrypted');
    // ignore: avoid_print
    print('Match: ${decrypted == testValue ? 'YES' : 'NO'}');

    // ignore: avoid_print
    print('\n--- Instructions ---');
    // ignore: avoid_print
    print('1. Open tools/aes-gcm/decrypt.html in your browser');
    // ignore: avoid_print
    print('2. Paste the encrypted value above');
    // ignore: avoid_print
    print('3. Enter password: $password');
    // ignore: avoid_print
    print('4. Click Decrypt - you should see: $testValue');

    expect(decrypted, equals(testValue));
  });
}
