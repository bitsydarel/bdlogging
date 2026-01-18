# BDLOGGING (Logging package)

A flutter logging package for dart and flutter.

Provide logging functionality with plug-ins log handlers.

## Getting started

BDLogging delegate come with two out-of-the-box log handler.

* ConsoleLogHandler (Log events to the console)
* FileLogHandler (Log events to one or multiple files)

You can create your own log handler that cover your need by implementing BDLogHandler.

You can add as many log handler message with be dispatched to them if meeting the requirement.
## Usage

### Encrypted logs (QA-friendly)

BDLogging ships with `EncryptedIsolateFileLogHandler` to protect sensitive
substrings in log messages (passwords, tokens, emails, phone numbers) while
keeping the rest of the message readable. Only the sensitive part of the
message is encrypted; timestamps and other log fields remain unchanged.

### Security Warning

**Error objects are not encrypted.** When logging errors using the `error`, `debug`, `warning`, or `log` methods, any sensitive information contained in the error object or exception will be logged in plaintext. Avoid including sensitive data such as passwords, API keys, or personal information in error objects.

```dart
// ⚠️ WARNING: This will log sensitive data in plaintext
logger.error('Login failed', Exception('Invalid credentials: password=secret123'));

// ✅ RECOMMENDED: Sanitize error messages
logger.error('Login failed', Exception('Invalid credentials provided'));
```

### Decrypting encrypted values

Each encryption algorithm has its own decryption tool and documentation:

| Algorithm | Encryptor Class | Decryption Guide |
|-----------|-----------------|------------------|
| AES-GCM | `AesGcmSensitiveDataEncryptor` | [tools/aes-gcm/](tools/aes-gcm/) |

**For QA/Support staff**: Each algorithm folder contains a browser-based decryption tool (`decrypt.html`) that requires no programming knowledge. Just open it in your browser, paste the encrypted value, and enter the password.

**For Developers**: Each algorithm folder contains code examples in Dart, Python, and JavaScript.

### Example usage in app

```dart
final handler = EncryptedIsolateFileLogHandler(
  Directory.current,
  encryptor: AesGcmSensitiveDataEncryptor('my-secret-password'),
  options: const EncryptedIsolateFileLogHandlerOptions(
    fileOptions: EncryptedLogFileOptions(
      logNamePrefix: 'secure',
    ),
  ),
);
```

###  Get an instance of BDLogger.

```dart
final BDLogger logger = BDLogger();
```

Note: BDLogger is a singleton so you can call it anywhere.

### Add your log handler.

```dart
logger.addHandler(new ConsoleLogHandler());
```

Note: 
* You can add as many log handler as you want.
* You can specify the BDLevel of logging messages that your log handler support.

```dart
final BDLogger logger = BDLogger();

logger.addHandler(new ConsoleLogHandler());

logger.addHandler(
  new FileLogHandler(
    logNamePrefix: 'example',
    maxLogSize: 5,
    maxFilesCount: 5,
    logFileDirectory: Directory.current,
    supportedLevels: <BDLevel>[BDLevel.error],
  ),
);
```
### Logging messages

You can log messages and errors using the current available method.

```dart
final BDLogger logger = BDLogger();

logger.debug(params);
logger.info(params);
logger.warning(params);
logger.error(params);
logger.log(params);
```

### Formatting logging messages

BDLogging the interface LogFormatter can be implemented to define how you would wish logging messages to be formatted.

Note: a Default log formatter is provided.
