import 'dart:async';
import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:bdlogging/src/handlers/isolate_file_log_handler.dart';
import 'package:bdlogging/src/security/sensitive_data_encryptor.dart';
import 'package:bdlogging/src/security/sensitive_data_matcher.dart';
import 'package:meta/meta.dart';

/// Handles encryption failures by returning a replacement string.
///
/// Use this to configure how the [EncryptedIsolateFileLogHandler] behaves
/// when encryption fails. The default behavior is to return the original
/// plaintext value, but this can be customized to return a marker string
/// or implement more advanced error handling.
mixin EncryptionFailureHandler {
  /// Called when encryption fails, returns the replacement value.
  ///
  /// The [originalValue] is the sensitive data that failed to encrypt.
  /// The [error] and [stackTrace] provide details about the failure.
  Future<String> onEncryptionFailed(
    String originalValue,
    Object error,
    StackTrace? stackTrace,
  );
}

/// Default handler that returns the original plaintext on encryption failure.
///
/// This preserves the original behavior but may leak sensitive data if
/// encryption consistently fails.
@immutable
class PlaintextFallbackHandler implements EncryptionFailureHandler {
  /// Creates a plaintext fallback handler.
  const PlaintextFallbackHandler();

  @override
  Future<String> onEncryptionFailed(
    String originalValue,
    Object error,
    StackTrace? stackTrace,
  ) async {
    return originalValue;
  }
}

/// Handler that returns a configurable marker string on encryption failure.
///
/// This prevents sensitive data leakage by replacing failed encryptions
/// with a fixed marker. The marker can be customized to indicate the
/// type of failure or location in logs.
@immutable
class MarkerFallbackHandler implements EncryptionFailureHandler {
  /// Creates a marker fallback handler with an optional custom marker.
  const MarkerFallbackHandler([this.marker = '[ENCRYPTION_FAILED]']);

  /// The marker string to use when encryption fails.
  final String marker;

  @override
  Future<String> onEncryptionFailed(
    String originalValue,
    Object error,
    StackTrace? stackTrace,
  ) async {
    return marker;
  }
}

/// Handler that redacts sensitive data on encryption failure.
///
/// This replaces the original value with asterisks of the same length,
/// providing some indication of the original data size while preventing
/// leakage.
@immutable
class RedactFallbackHandler implements EncryptionFailureHandler {
  /// Creates a redact fallback handler with an optional redaction character.
  const RedactFallbackHandler([this.redactionChar = '*']);

  /// The character used to redact sensitive data.
  final String redactionChar;

  @override
  Future<String> onEncryptionFailed(
    String originalValue,
    Object error,
    StackTrace? stackTrace,
  ) async {
    return redactionChar * originalValue.length;
  }
}

/// Options for log file handling in encrypted handlers.
class EncryptedLogFileOptions {
  /// Creates log file options with defaults.
  const EncryptedLogFileOptions({
    this.maxFilesCount = 5,
    this.logNamePrefix = '_log',
    this.maxLogSizeInMb = 5,
    this.supportedLevels = const <BDLevel>[
      BDLevel.warning,
      BDLevel.success,
      BDLevel.error,
    ],
  });

  /// Maximum count of files to keep.
  final int maxFilesCount;

  /// Prefix of each log file created by this handler.
  final String logNamePrefix;

  /// Maximum size of a log file in MB.
  final int maxLogSizeInMb;

  /// Supported [BDLevel] of [BDLogRecord].
  final List<BDLevel> supportedLevels;
}

/// Options for configuring [EncryptedIsolateFileLogHandler].
@immutable
class EncryptedIsolateFileLogHandlerOptions {
  /// Creates handler options with defaults.
  const EncryptedIsolateFileLogHandlerOptions({
    this.fileOptions = const EncryptedLogFileOptions(),
    this.matcher,
    this.logFunction,
    this.encryptionFailureHandler,
  });

  /// File options for log rotation and levels.
  final EncryptedLogFileOptions fileOptions;

  /// Matcher for sensitive substrings.
  final SensitiveDataMatcher? matcher;

  /// Custom log function for internal errors.
  final LogFunction? logFunction;

  /// Handler for encryption failures.
  ///
  /// Defaults to [PlaintextFallbackHandler] if not specified.
  /// Consider using [MarkerFallbackHandler] or [RedactFallbackHandler]
  /// to prevent sensitive data leakage on encryption failures.
  final EncryptionFailureHandler? encryptionFailureHandler;
}

/// Isolate file log handler that encrypts sensitive substrings
/// inside [BDLogRecord.message] before persisting to disk.
///
/// **Security Note:** The [BDLogRecord.error] field is not encrypted and may
/// contain sensitive information. Avoid including sensitive data in error
/// objects as they will be logged in plaintext.
class EncryptedIsolateFileLogHandler extends IsolateFileLogHandler {
  /// Creates an encrypted isolate file log handler.
  EncryptedIsolateFileLogHandler(
    super.logFileDirectory, {
    required this.encryptor,
    EncryptedIsolateFileLogHandlerOptions options =
        const EncryptedIsolateFileLogHandlerOptions(),
  })  : matcher = options.matcher ?? RegexSensitiveDataMatcher(),
        _logFunction = options.logFunction,
        _encryptionFailureHandler = options.encryptionFailureHandler ??
            const PlaintextFallbackHandler(),
        super(
          maxFilesCount: options.fileOptions.maxFilesCount,
          logNamePrefix: options.fileOptions.logNamePrefix,
          maxLogSizeInMb: options.fileOptions.maxLogSizeInMb,
          supportedLevels: options.fileOptions.supportedLevels,
          logFunction: options.logFunction,
        );

  /// Encryptor responsible for reversible encryption.
  final SensitiveDataEncryptor encryptor;

  /// Matcher for sensitive substrings.
  final SensitiveDataMatcher matcher;

  final LogFunction? _logFunction;
  final EncryptionFailureHandler _encryptionFailureHandler;

  Future<void> _pendingWrite = Future<void>.value();

  @override
  Future<void> handleRecord(BDLogRecord record) {
    return _queueWrite(() => _processRecord(record));
  }

  @override
  Future<void> clean() async {
    await _pendingWrite;
    matcher.dispose();
    return super.clean();
  }

  Future<void> _queueWrite(Future<void> Function() action) {
    return _pendingWrite =
        _pendingWrite.then((_) => action()).catchError(_logError);
  }

  Future<void> _processRecord(BDLogRecord record) async {
    final BDLogRecord sanitizedRecord = await _sanitizeRecord(record);
    await super.handleRecord(sanitizedRecord);
  }

  Future<BDLogRecord> _sanitizeRecord(BDLogRecord record) async {
    final String sanitizedMessage =
        await _encryptSensitiveSubstrings(record.message);
    return BDLogRecord(
      record.level,
      sanitizedMessage,
      error: record.error,
      stackTrace: record.stackTrace,
      isFatal: record.isFatal,
      time: record.time,
    );
  }

  Future<String> _encryptSensitiveSubstrings(String message) async {
    final List<SensitiveMatch> matches = _orderedMatches(message);
    if (matches.isEmpty) {
      return message;
    }

    return _buildEncryptedMessage(message, matches);
  }

  Future<String> _buildEncryptedMessage(
    String message,
    List<SensitiveMatch> matches,
  ) async {
    final StringBuffer buffer = StringBuffer();
    int currentIndex = 0;

    for (final SensitiveMatch match in matches) {
      if (_skipMatch(match, currentIndex, message.length)) {
        continue;
      }

      buffer
        ..write(_substring(message, currentIndex, match.start))
        ..write(await _encryptedSubstring(message, match));
      currentIndex = match.end;
    }

    if (currentIndex < message.length) {
      buffer.write(message.substring(currentIndex));
    }

    return buffer.toString();
  }

  Future<String> _encryptedSubstring(
    String message,
    SensitiveMatch match,
  ) {
    return _encryptValue(message.substring(match.start, match.end));
  }

  List<SensitiveMatch> _orderedMatches(String message) {
    return _orderMatches(matcher.findMatches(message).toList());
  }

  bool _skipMatch(SensitiveMatch match, int currentIndex, int length) {
    return _isBeforeCurrentIndex(match, currentIndex) ||
        _isOutOfBounds(match, length);
  }

  bool _isBeforeCurrentIndex(SensitiveMatch match, int currentIndex) {
    return match.start < currentIndex;
  }

  bool _isOutOfBounds(SensitiveMatch match, int length) {
    return match.start > length || match.end > length;
  }

  String _substring(String message, int start, int end) {
    return message.substring(start, end);
  }

  Future<String> _encryptValue(String value) async {
    try {
      return await encryptor.encrypt(value);
    } on Object catch (error, stackTrace) {
      return _encryptionFailureHandler.onEncryptionFailed(
        value,
        error,
        stackTrace,
      );
    }
  }

  void _logError(Object error, [StackTrace? stackTrace]) {
    final LogFunction? logger = _logFunction;
    if (logger == null) {
      return;
    }
    logger(
      'Encrypted handler write failed',
      error: error,
      stackTrace: stackTrace,
    );
  }

  List<SensitiveMatch> _orderMatches(List<SensitiveMatch> matches) {
    if (matches.isEmpty) {
      return matches;
    }

    matches.sort((SensitiveMatch a, SensitiveMatch b) {
      final int startCompare = a.start.compareTo(b.start);
      if (startCompare != 0) {
        return startCompare;
      }
      return a.end.compareTo(b.end);
    });

    return _dedupeMatches(matches);
  }

  List<SensitiveMatch> _dedupeMatches(List<SensitiveMatch> matches) {
    final List<SensitiveMatch> deduped = <SensitiveMatch>[];
    for (final SensitiveMatch match in matches) {
      if (_shouldAddMatch(deduped, match)) {
        deduped.add(match);
      }
    }
    return deduped;
  }

  bool _shouldAddMatch(List<SensitiveMatch> deduped, SensitiveMatch match) {
    if (deduped.isEmpty) {
      return true;
    }
    final SensitiveMatch last = deduped.last;
    return match.start >= last.end;
  }
}
