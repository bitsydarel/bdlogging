import 'dart:io';

import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:bdlogging/src/handlers/encrypted_isolate_file_log_handler.dart';
import 'package:bdlogging/src/security/sensitive_data_encryptor.dart';
import 'package:bdlogging/src/security/sensitive_data_matcher.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

int _readEnvInt(String name, int fallback) {
  return int.tryParse(Platform.environment[name] ?? '') ?? fallback;
}

void _sinkLog(
  String message, {
  Object? error,
  StackTrace? stackTrace,
}) {}

class FailingEncryptor implements SensitiveDataEncryptor {
  @override
  Future<String> decrypt(String value) {
    throw UnimplementedError();
  }

  @override
  Future<String> encrypt(String value) {
    throw StateError('Encryption failed');
  }
}

class PassThroughEncryptor implements SensitiveDataEncryptor {
  @override
  Future<String> decrypt(String value) async => value;

  @override
  Future<String> encrypt(String value) async => value;
}

void main() {
  late Directory testDirectory;
  late String uniqueDirName;

  String readLogContent(String prefix) {
    final List<FileSystemEntity> files = testDirectory.listSync();
    final List<File> logFiles = files
        .whereType<File>()
        .where((File file) => file.path.contains(prefix))
        .toList();

    expect(logFiles, isNotEmpty);
    return logFiles.first.readAsStringSync();
  }

  setUp(() {
    uniqueDirName =
        'encrypted_isolate_${DateTime.now().microsecondsSinceEpoch}';
    testDirectory = Directory(
      path.join(Directory.current.path, 'test/resources', uniqueDirName),
    )..createSync(recursive: true);
  });

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (testDirectory.existsSync()) {
      testDirectory.deleteSync(recursive: true);
    }
  });

  test('encrypts sensitive substrings in message', () async {
    final SensitiveDataEncryptor encryptor =
        AesGcmSensitiveDataEncryptor('qa-password');
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: encryptor,
      options: const EncryptedIsolateFileLogHandlerOptions(
        fileOptions: EncryptedLogFileOptions(
          logNamePrefix: 'encrypted_handler',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    final BDLogRecord record = BDLogRecord(
      BDLevel.error,
      'Login failed password=supersecret email=qa@example.com',
    );

    await handler.handleRecord(record);
    await handler.clean();

    final String content = readLogContent('encrypted_handler');

    expect(content, contains('Login failed'));
    expect(content, isNot(contains('supersecret')));
    expect(content, isNot(contains('qa@example.com')));
  });

  test('leaves message intact when no sensitive matches', () async {
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: AesGcmSensitiveDataEncryptor('qa-password'),
      options: const EncryptedIsolateFileLogHandlerOptions(
        fileOptions: EncryptedLogFileOptions(
          logNamePrefix: 'no_sensitive',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    await handler.handleRecord(
      BDLogRecord(BDLevel.info, 'All good nothing to hide'),
    );
    await handler.clean();

    final String content = readLogContent('no_sensitive');

    expect(content, contains('All good nothing to hide'));
  });

  test('preserves original record timestamp', () async {
    final DateTime time = DateTime.parse('2025-01-20T12:34:56.000Z');
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: PassThroughEncryptor(),
      options: const EncryptedIsolateFileLogHandlerOptions(
        fileOptions: EncryptedLogFileOptions(
          logNamePrefix: 'time_preserve',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    await handler.handleRecord(
      BDLogRecord(BDLevel.info, 'password=keep', time: time),
    );
    await handler.clean();

    final String content = readLogContent('time_preserve');
    final String formatted = DateFormat('dd-MM-yyyy H:m:s').format(time);

    expect(content, contains(formatted));
  });

  test('falls back to plaintext when encryption fails', () async {
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: FailingEncryptor(),
      options: const EncryptedIsolateFileLogHandlerOptions(
        logFunction: _sinkLog,
        fileOptions: EncryptedLogFileOptions(
          logNamePrefix: 'fallback_plaintext',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    await handler.handleRecord(
      BDLogRecord(BDLevel.info, 'password=fallback'),
    );
    await handler.clean();

    final String content = readLogContent('fallback_plaintext');

    expect(content, contains('password=fallback'));
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('supports custom matcher and encryptor', () async {
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: PassThroughEncryptor(),
      options: EncryptedIsolateFileLogHandlerOptions(
        matcher: RegexSensitiveDataMatcher(
          patterns: <SensitivePattern>[
            SensitivePattern(RegExp(r'secret=([^\s]+)'), group: 1),
          ],
        ),
        fileOptions: const EncryptedLogFileOptions(
          logNamePrefix: 'custom_matcher',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    await handler.handleRecord(
      BDLogRecord(BDLevel.info, 'secret=value'),
    );
    await handler.clean();

    final String content = readLogContent('custom_matcher');

    expect(content, contains('secret=value'));
  });

  test('handles overlapping matches without dropping data', () async {
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: PassThroughEncryptor(),
      options: EncryptedIsolateFileLogHandlerOptions(
        matcher: RegexSensitiveDataMatcher(
          patterns: <SensitivePattern>[
            SensitivePattern(RegExp(r'token=([^\s]+)'), group: 1),
            SensitivePattern(RegExp('token=abc123')),
          ],
        ),
        fileOptions: const EncryptedLogFileOptions(
          logNamePrefix: 'overlap_matcher',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    await handler.handleRecord(
      BDLogRecord(BDLevel.info, 'token=abc123'),
    );
    await handler.clean();

    final String content = readLogContent('overlap_matcher');

    expect(content, contains('token=abc123'));
  });

  test('writes records in the order they were received', () async {
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: PassThroughEncryptor(),
      options: const EncryptedIsolateFileLogHandlerOptions(
        fileOptions: EncryptedLogFileOptions(
          logNamePrefix: 'ordered_records',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    const int recordCount = 100;
    for (int i = 0; i < recordCount; i++) {
      await handler.handleRecord(
        BDLogRecord(BDLevel.info, 'message-$i'),
      );
    }
    await handler.clean();

    final String content = readLogContent('ordered_records');

    int lastIndex = -1;
    for (int i = 0; i < recordCount; i++) {
      final int index = content.indexOf('message-$i');
      expect(index, greaterThan(lastIndex));
      lastIndex = index;
    }
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('does not encrypt error field', () async {
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: AesGcmSensitiveDataEncryptor('test-key'),
      options: EncryptedIsolateFileLogHandlerOptions(
        matcher: RegexSensitiveDataMatcher(),
        fileOptions: const EncryptedLogFileOptions(
          logNamePrefix: 'error_test',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    const String sensitiveError = 'Exception with password=secret123';
    final Exception error = Exception(sensitiveError);

    await handler.handleRecord(
      BDLogRecord(
        BDLevel.error,
        'Login failed with password=secret123',
        error: error,
      ),
    );
    await handler.clean();

    final String content = readLogContent('error_test');

    // Message should have sensitive data encrypted
    expect(content, contains('Login failed'));
    // Check that the message part (before "Exception:") doesn't contain plaintext password
    final int exceptionIndex = content.indexOf('Exception:');
    final String messagePart = content.substring(0, exceptionIndex);
    expect(messagePart, isNot(contains('password=secret123')));

    // Error field should NOT be encrypted (remains in plaintext)
    expect(content, contains('Exception: Exception with password=secret123'));
  });

  test('handles high volume within time budget', () async {
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: PassThroughEncryptor(),
      options: const EncryptedIsolateFileLogHandlerOptions(
        fileOptions: EncryptedLogFileOptions(
          logNamePrefix: 'volume_budget',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    final int recordCount = _readEnvInt('BDLOG_HANDLER_LOAD', 20000);
    final int budgetSeconds = _readEnvInt('BDLOG_HANDLER_BUDGET', 6);
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<Future<void>> writes = <Future<void>>[];
    for (int i = 0; i < recordCount; i++) {
      writes.add(
        handler.handleRecord(
          BDLogRecord(BDLevel.info, 'bulk-$i'),
        ),
      );
    }
    await Future.wait(writes);
    await handler.clean();
    stopwatch.stop();

    expect(stopwatch.elapsed.inSeconds, lessThan(budgetSeconds));
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('clean completes while logs are in flight', () async {
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: PassThroughEncryptor(),
      options: const EncryptedIsolateFileLogHandlerOptions(
        fileOptions: EncryptedLogFileOptions(
          logNamePrefix: 'clean_in_flight',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    final List<Future<void>> writes = <Future<void>>[];
    for (int i = 0; i < 200; i++) {
      writes.add(
        handler.handleRecord(
          BDLogRecord(BDLevel.info, 'flight-$i'),
        ),
      );
    }

    final Future<void> cleanFuture = handler.clean();
    await Future.wait(writes);
    await cleanFuture;

    final String content = readLogContent('clean_in_flight');
    expect(content, contains('flight-0'));
  }, timeout: const Timeout(Duration(seconds: 10)));
}
