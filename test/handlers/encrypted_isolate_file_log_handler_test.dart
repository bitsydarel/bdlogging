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

class MarkerEncryptor implements SensitiveDataEncryptor {
  const MarkerEncryptor();

  @override
  Future<String> decrypt(String value) async => value;

  @override
  Future<String> encrypt(String value) async => '[ENC]';
}

class FixedMatcher extends SensitiveDataMatcher {
  FixedMatcher(this.matches);

  final List<SensitiveMatch> matches;

  @override
  Iterable<SensitiveMatch> findMatches(String message) => matches;
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

  test('encrypts authorization bearer tokens', () async {
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: const MarkerEncryptor(),
      options: const EncryptedIsolateFileLogHandlerOptions(
        fileOptions: EncryptedLogFileOptions(
          logNamePrefix: 'auth_bearer',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    await handler.handleRecord(
      BDLogRecord(
        BDLevel.info,
        'Authorization:\nBearer\tabc123',
      ),
    );
    await handler.clean();

    final String content = readLogContent('auth_bearer');

    expect(content, contains('Authorization'));
    expect(content, contains('Bearer'));
    expect(content, contains('[ENC]'));
    expect(content, isNot(contains('abc123')));
  });

  test('encrypts authorization bearer tokens in quoted values', () async {
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: const MarkerEncryptor(),
      options: const EncryptedIsolateFileLogHandlerOptions(
        fileOptions: EncryptedLogFileOptions(
          logNamePrefix: 'auth_bearer_quoted',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    await handler.handleRecord(
      BDLogRecord(
        BDLevel.info,
        '"Authorization": "Bearer abc123"',
      ),
    );
    await handler.clean();

    final String content = readLogContent('auth_bearer_quoted');

    expect(content, contains('Authorization'));
    expect(content, contains('Bearer'));
    expect(content, contains('[ENC]'));
    expect(content, isNot(contains('abc123')));
  });

  test('encrypts authorization basic credentials', () async {
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: const MarkerEncryptor(),
      options: const EncryptedIsolateFileLogHandlerOptions(
        fileOptions: EncryptedLogFileOptions(
          logNamePrefix: 'auth_basic',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    await handler.handleRecord(
      BDLogRecord(BDLevel.info, 'authorization=Basic dXNlcjpwYXNz'),
    );
    await handler.clean();

    final String content = readLogContent('auth_basic');

    expect(content, contains('Basic'));
    expect(content, contains('[ENC]'));
    expect(content, isNot(contains('dXNlcjpwYXNz')));
  });

  test('encrypts authorization basic credentials in quoted values', () async {
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: const MarkerEncryptor(),
      options: const EncryptedIsolateFileLogHandlerOptions(
        fileOptions: EncryptedLogFileOptions(
          logNamePrefix: 'auth_basic_quoted',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    await handler.handleRecord(
      BDLogRecord(
        BDLevel.info,
        'Authorization = "Basic dXNlcjpwYXNz"',
      ),
    );
    await handler.clean();

    final String content = readLogContent('auth_basic_quoted');

    expect(content, contains('Basic'));
    expect(content, contains('[ENC]'));
    expect(content, isNot(contains('dXNlcjpwYXNz')));
  });

  test('encrypts api key variants', () async {
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: const MarkerEncryptor(),
      options: const EncryptedIsolateFileLogHandlerOptions(
        fileOptions: EncryptedLogFileOptions(
          logNamePrefix: 'api_key',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    await handler.handleRecord(
      BDLogRecord(BDLevel.info, 'X-API-KEY: key-123'),
    );
    await handler.clean();

    final String content = readLogContent('api_key');

    expect(content, contains('[ENC]'));
    expect(content, isNot(contains('key-123')));
  });

  test('encrypts query string values separately', () async {
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: const MarkerEncryptor(),
      options: const EncryptedIsolateFileLogHandlerOptions(
        fileOptions: EncryptedLogFileOptions(
          logNamePrefix: 'query_string',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    await handler.handleRecord(
      BDLogRecord(
        BDLevel.info,
        'token=tok-123&api_key=api-456&other=ok',
      ),
    );
    await handler.clean();

    final String content = readLogContent('query_string');
    final int markerCount = RegExp(r'\[ENC\]').allMatches(content).length;

    expect(content, contains('token='));
    expect(content, contains('api_key='));
    expect(content, contains('&other=ok'));
    expect(markerCount, equals(2));
    expect(content, isNot(contains('tok-123')));
    expect(content, isNot(contains('api-456')));
  });

  test('keeps device, member, and location plaintext', () async {
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: const MarkerEncryptor(),
      options: const EncryptedIsolateFileLogHandlerOptions(
        fileOptions: EncryptedLogFileOptions(
          logNamePrefix: 'plaintext_fields',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    const String message = 'deviceId=ab5ee99a3cbc88b1 '
        'memberId=f47a7f89-c512-428a-944d-18730e5abb5b '
        'location=Germa, Oitylo, GR';
    await handler.handleRecord(BDLogRecord(BDLevel.info, message));
    await handler.clean();

    final String content = readLogContent('plaintext_fields');

    expect(content, contains('deviceId=ab5ee99a3cbc88b1'));
    expect(content, contains('memberId=f47a7f89-c512-428a-944d-18730e5abb5b'));
    expect(content, contains('location=Germa, Oitylo, GR'));
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

  test('merges overlapping matches to avoid plaintext gaps', () async {
    const String message = 'prefix-OVERLAPSEGMENT-suffix';
    final int start1 = message.indexOf('OVERLAP');
    final int end1 = start1 + 'OVERLAP'.length;
    final int start2 = message.indexOf('LAPSEGMENT');
    final int end2 = start2 + 'LAPSEGMENT'.length;
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: const MarkerEncryptor(),
      options: EncryptedIsolateFileLogHandlerOptions(
        matcher: FixedMatcher(
          <SensitiveMatch>[
            SensitiveMatch(start: start1, end: end1),
            SensitiveMatch(start: start2, end: end2),
          ],
        ),
        fileOptions: const EncryptedLogFileOptions(
          logNamePrefix: 'overlap_merge',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    await handler.handleRecord(BDLogRecord(BDLevel.info, message));
    await handler.clean();

    final String content = readLogContent('overlap_merge');

    expect(content, contains('prefix-'));
    expect(content, contains('-suffix'));
    expect(content, contains('[ENC]'));
    expect(content, isNot(contains('OVERLAP')));
    expect(content, isNot(contains('SEGMENT')));
    expect(content, isNot(contains('OVERLAPSEGMENT')));
  });

  test('merges adjacent matches to avoid plaintext gaps', () async {
    const String message = 'prefix-ABCDEF-suffix';
    final int start1 = message.indexOf('ABC');
    final int end1 = start1 + 'ABC'.length;
    final int start2 = message.indexOf('DEF');
    final int end2 = start2 + 'DEF'.length;
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: const MarkerEncryptor(),
      options: EncryptedIsolateFileLogHandlerOptions(
        matcher: FixedMatcher(
          <SensitiveMatch>[
            SensitiveMatch(start: start1, end: end1),
            SensitiveMatch(start: start2, end: end2),
          ],
        ),
        fileOptions: const EncryptedLogFileOptions(
          logNamePrefix: 'adjacent_merge',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    await handler.handleRecord(BDLogRecord(BDLevel.info, message));
    await handler.clean();

    final String content = readLogContent('adjacent_merge');

    expect(content, contains('prefix-'));
    expect(content, contains('-suffix'));
    expect(content, contains('[ENC]'));
    expect(content, isNot(contains('ABC')));
    expect(content, isNot(contains('DEF')));
    expect(content, isNot(contains('ABCDEF')));
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
    // Check that the message part (before "Exception:") doesn't contain
    // plaintext password.
    final int exceptionIndex = content.indexOf('Exception:');
    final String messagePart = content.substring(0, exceptionIndex);
    expect(messagePart, isNot(contains('password=secret123')));

    // Error field should NOT be encrypted (remains in plaintext)
    expect(content, contains('Exception: Exception with password=secret123'));
  });

  test('does not encrypt stack trace field', () async {
    final EncryptedIsolateFileLogHandler handler =
        EncryptedIsolateFileLogHandler(
      testDirectory,
      encryptor: const MarkerEncryptor(),
      options: const EncryptedIsolateFileLogHandlerOptions(
        fileOptions: EncryptedLogFileOptions(
          logNamePrefix: 'stack_trace',
          supportedLevels: BDLevel.values,
        ),
      ),
    );

    const String stackTraceLine = 'StackTrace token=secret123';
    final StackTrace stackTrace = StackTrace.fromString(stackTraceLine);

    await handler.handleRecord(
      BDLogRecord(
        BDLevel.error,
        'Login failed token=secret123',
        stackTrace: stackTrace,
      ),
    );
    await handler.clean();

    final String content = readLogContent('stack_trace');
    expect(content, contains(stackTraceLine));
    final int stackTraceIndex = content.indexOf(stackTraceLine);
    final String messagePart = content.substring(0, stackTraceIndex);

    expect(messagePart, isNot(contains('token=secret123')));
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
