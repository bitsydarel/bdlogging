# AES-GCM Decryption Guide

This guide explains how to decrypt sensitive values encrypted with `AesGcmSensitiveDataEncryptor` in BDLogging.

## For QA and Support Staff (No Programming Required)

### Using the Browser Tool

1. **Open the decryption tool**: Open [`decrypt.html`](decrypt.html) in your web browser (Chrome, Firefox, Safari, or Edge)

2. **Paste the encrypted value**: Copy the long base64 text from the log file and paste it into the "Encrypted Value" box

3. **Enter the password**: Type the decryption password (ask your development team if you don't have it)

4. **Click "Decrypt"**: The original value will appear below

### What Encrypted Values Look Like in Logs

Only the sensitive part of a log message is encrypted. For example:

```
Login failed password=supersecret email=qa@example.com
```

becomes:

```
Login failed password=dGhpcyBpcyBhIGJhc2U2NCBleGFtcGxl... email=YW5vdGhlciBiYXNlNjQgc3RyaW5n...
```

The base64 strings (long text with letters, numbers, `+`, `/`, and `=`) are what you copy and decrypt.

### Troubleshooting

| Problem | Solution |
|---------|----------|
| "Password is incorrect" | Double-check the password with your dev team |
| "Invalid encrypted value" | Make sure you copied the entire base64 string (no extra spaces or missing characters) |
| Tool won't open | Open it in a modern web browser (Chrome, Firefox, Safari, Edge), not a text editor |
| Blank result | The original value might have been empty |

### Privacy Note

The decryption tool runs entirely in your browser. No data is sent to any server.

---

## For Developers

### Encryption Format

| Component | Size | Description |
|-----------|------|-------------|
| Salt | 16 bytes | Random salt for key derivation |
| Nonce/IV | 12 bytes | Random nonce for AES-GCM |
| Ciphertext | variable | Encrypted data |
| Tag | 16 bytes | Authentication tag |

**Payload layout (base64 encoded):**
```
[salt(16) | nonce(12) | ciphertext | tag(16)]
```

### Key Derivation

- **Algorithm**: PBKDF2-HMAC-SHA256
- **Iterations**: 20,000 (default, configurable via `AesGcmEncryptionOptions`)
- **Output**: 256-bit key

### Cipher

- **Algorithm**: AES-GCM
- **Key size**: 256 bits
- **Nonce size**: 12 bytes (96 bits)
- **Tag size**: 16 bytes (128 bits)

### Dart Decryption Code

```dart
import 'dart:convert';
import 'package:cryptography/cryptography.dart';

Future<String> decryptLogValue(String base64Text, String password, {int iterations = 20000}) async {
  final data = base64Decode(base64Text);
  const int saltLength = 16;
  const int nonceLength = 12;

  final salt = data.sublist(0, saltLength);
  final nonce = data.sublist(saltLength, saltLength + nonceLength);
  final macLength = AesGcm.with256bits().macAlgorithm.macLength;
  final macStart = data.length - macLength;
  final cipherText = data.sublist(saltLength + nonceLength, macStart);
  final macBytes = data.sublist(macStart);

  final pbkdf2 = Pbkdf2.hmacSha256(iterations: iterations, bits: 256);
  final secretKey = await pbkdf2.deriveKeyFromPassword(
    password: password,
    nonce: salt,
  );

  final clearText = await AesGcm.with256bits().decrypt(
    SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
    secretKey: secretKey,
  );

  return utf8.decode(clearText);
}
```

### Other Languages

The same decryption logic works in any language with AES-GCM support. Key parameters:

| Parameter | Value |
|-----------|-------|
| Cipher | AES-GCM (256-bit key) |
| Key derivation | PBKDF2-HMAC-SHA256 |
| Iterations | 20,000 (default) |
| Salt length | 16 bytes |
| Nonce length | 12 bytes |
| Tag length | 16 bytes |

#### Python Example

```python
import base64
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes

def decrypt_log_value(base64_text: str, password: str, iterations: int = 20000) -> str:
    data = base64.b64decode(base64_text)

    salt = data[:16]
    nonce = data[16:28]
    ciphertext_with_tag = data[28:]

    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=iterations,
    )
    key = kdf.derive(password.encode())

    aesgcm = AESGCM(key)
    plaintext = aesgcm.decrypt(nonce, ciphertext_with_tag, None)

    return plaintext.decode('utf-8')
```

#### JavaScript/Node.js Example

```javascript
const crypto = require('crypto');

async function decryptLogValue(base64Text, password, iterations = 20000) {
  const data = Buffer.from(base64Text, 'base64');

  const salt = data.subarray(0, 16);
  const nonce = data.subarray(16, 28);
  const ciphertextWithTag = data.subarray(28);

  // Derive key using PBKDF2
  const key = crypto.pbkdf2Sync(password, salt, iterations, 32, 'sha256');

  // Decrypt using AES-GCM
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, nonce);
  const tag = ciphertextWithTag.subarray(ciphertextWithTag.length - 16);
  const ciphertext = ciphertextWithTag.subarray(0, ciphertextWithTag.length - 16);

  decipher.setAuthTag(tag);
  const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]);

  return decrypted.toString('utf-8');
}
```
