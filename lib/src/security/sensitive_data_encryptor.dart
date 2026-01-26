import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart';

/// Encrypts and decrypts sensitive strings.
abstract class SensitiveDataEncryptor {
  /// Encrypts [value] into a reversible string.
  Future<String> encrypt(String value);

  /// Decrypts [value] back to its original clear text.
  Future<String> decrypt(String value);
}

/// Configuration options for [AesGcmSensitiveDataEncryptor].
///
/// These options are specific to the AES-GCM encryption algorithm.
/// Other encryption algorithms may require different configuration.
@immutable
class AesGcmEncryptionOptions {
  /// Creates encryption options.
  ///
  /// The [iterations] parameter controls PBKDF2 key derivation strength.
  /// The default of 20,000 iterations provides a balance between security
  /// and performance for logging use cases. For higher security requirements
  /// (e.g., long-term storage of highly sensitive data), consider using
  /// 100,000+ iterations. OWASP recommends 600,000+ for PBKDF2-SHA256 in
  /// password storage scenarios, but this may be excessive for log encryption
  /// where performance is critical.
  const AesGcmEncryptionOptions({
    this.iterations = 20000,
    this.saltLength = 16,
    this.nonceLength,
    this.random,
  });

  /// Number of PBKDF2 iterations for key derivation.
  ///
  /// Higher values increase security but also increase CPU time for
  /// encryption/decryption. The default of 20,000 is suitable for
  /// general logging use cases. Consider increasing this value for
  /// highly sensitive data or when logs may be stored long-term.
  final int iterations;

  /// Salt length in bytes.
  final int saltLength;

  /// Nonce length in bytes.
  final int? nonceLength;

  /// Random source used for salt and nonce creation.
  final Random? random;
}

/// AES-GCM based sensitive data encryptor.
///
/// Payload format (base64):
/// [salt(16) | nonce(12) | ciphertext | tag(16)]
///
/// Key derivation: PBKDF2-HMAC-SHA256.
///
/// ## Salt Reuse Behavior
///
/// Each instance generates a single random salt during construction and
/// reuses it for all encryption operations during that session. This means:
///
/// - All encrypted values from one session share the same derived key
/// - A unique nonce is generated per encryption (required for AES-GCM security)
/// - If the derived key is compromised, all values encrypted in that session
///   are compromised
/// - Decryption requires both the encrypted value and the original password
///
/// This design is acceptable for logging use cases where:
/// - Sessions are typically short-lived
/// - Performance is important (key derivation happens once)
/// - Values are encrypted for the same recipient
@immutable
class AesGcmSensitiveDataEncryptor implements SensitiveDataEncryptor {
  /// Creates a new encryptor using the provided [password].
  AesGcmSensitiveDataEncryptor(
    this.password, {
    AesGcmEncryptionOptions options = const AesGcmEncryptionOptions(),
  })  : iterations = options.iterations,
        saltLength = options.saltLength,
        _nonceLength = options.nonceLength ?? AesGcm.with256bits().nonceLength,
        _random = options.random ?? Random.secure() {
    _cipher = AesGcm.with256bits(nonceLength: _nonceLength);
    _keyDerivation = Pbkdf2.hmacSha256(
      iterations: iterations,
      bits: _cipher.secretKeyLength * 8,
    );
    _salt = _randomBytes(saltLength);
    _secretKey = _deriveKey(_salt);
  }

  /// Password used to derive the encryption key.
  final String password;

  /// Number of PBKDF2 iterations for key derivation.
  final int iterations;

  /// Salt length in bytes.
  final int saltLength;

  final Random _random;
  late final Cipher _cipher;
  late final KdfAlgorithm _keyDerivation;
  late final int _nonceLength;
  late final Uint8List _salt;
  late final Future<SecretKey> _secretKey;

  @override
  Future<String> encrypt(String value) async {
    if (value.isEmpty) {
      return value;
    }

    final SecretKey secretKey = await _secretKey;
    final Uint8List nonce = _randomBytes(_nonceLength);

    final SecretBox encrypted = await _cipher.encrypt(
      utf8.encode(value),
      secretKey: secretKey,
      nonce: nonce,
    );

    final BytesBuilder builder = BytesBuilder(copy: false)
      ..add(_salt)
      ..add(nonce)
      ..add(encrypted.cipherText)
      ..add(encrypted.mac.bytes);

    return base64Encode(builder.toBytes());
  }

  @override
  Future<String> decrypt(String value) async {
    if (value.isEmpty) {
      return value;
    }

    final Uint8List data = base64Decode(value);
    if (data.length <
        saltLength + _nonceLength + _cipher.macAlgorithm.macLength) {
      throw StateError('Encrypted payload is too short.');
    }

    final int macLength = _cipher.macAlgorithm.macLength;
    final Uint8List salt = data.sublist(0, saltLength);
    final int nonceStart = saltLength;
    final int nonceEnd = nonceStart + _nonceLength;
    final Uint8List nonce = data.sublist(nonceStart, nonceEnd);
    final int macStart = data.length - macLength;
    final Uint8List cipherText = data.sublist(nonceEnd, macStart);
    final Uint8List macBytes = data.sublist(macStart);

    final SecretKey secretKey = await _deriveKey(salt);

    final List<int> clearText = await _cipher.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
      secretKey: secretKey,
    );

    return utf8.decode(clearText);
  }

  Future<SecretKey> _deriveKey(Uint8List salt) {
    return _keyDerivation.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
  }

  Uint8List _randomBytes(int length) {
    final Uint8List bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }
}
