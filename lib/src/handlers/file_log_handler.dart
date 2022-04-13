import 'dart:io';

import 'package:bdlogging/src/bd_cleanable_log_handler.dart';
import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_formatter.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:bdlogging/src/formatters/default_log_formatter.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// A implementation of [BDCleanableLogHandler]
/// that write [BDLogRecord] to files.
class FileLogHandler extends BDCleanableLogHandler {
  /// Create a new instance of [FileLogHandler].
  ///
  /// [logNamePrefix] will be used as prefix
  /// for each log file created by the instance of this [FileLogHandler].
  /// It's recommended that the [logNamePrefix] be unique in the app.
  ///
  /// [maxLogSize] in MB will be used as the maximum size of each
  /// log file created by the instance of this [FileLogHandler].
  ///
  /// [maxFilesCount] will be used to deleted old log files.
  /// If in the [logFileDirectory] there's files with prefix [logNamePrefix]
  /// and the count of files is greater than [maxFilesCount],
  /// older files will be deleted.
  ///
  /// [logFileDirectory] is the directory where log files will be stored.
  ///
  /// We assume that the [logFileDirectory] provide exist in the file system.
  ///
  /// [minimumSupportedLevel] will be used to discard [BDLogRecord] with
  /// [BDLevel] lower than [minimumSupportedLevel].
  FileLogHandler({
    required this.logNamePrefix,
    required this.maxLogSize,
    required this.maxFilesCount,
    required this.logFileDirectory,
    this.minimumSupportedLevel = BDLevel.warning,
    this.logFormatter = const DefaultLogFormatter(),
  })  : assert(
          logNamePrefix.isNotEmpty,
          'logNamePrefix should not be empty',
        ),
        assert(
          maxLogSize > 0,
          'maxLogSize should not be lower than zero',
        );

  /// Prefix of each log files created by this [FileLogHandler].
  final String logNamePrefix;

  /// Maximum size of a log file.
  final int maxLogSize;

  /// Maximum count of files to keep.
  final int maxFilesCount;

  /// Directory where to store the log files.
  final Directory logFileDirectory;

  /// Minimum supported [BDLevel] for [BDLogRecord].
  final BDLevel minimumSupportedLevel;

  /// [BDLogFormatter] that define how [BDLogRecord] should be written.
  final BDLogFormatter logFormatter;

  /// The suffix added after the [logNamePrefix] followed by the log file index.
  @visibleForTesting
  static const String logFileNameSuffix = '_log';

  /// The writer to perform operations on the [currentLogFile]
  @visibleForTesting
  RandomAccessFile? writer;

  /// The current log file that logs are written to.
  /// If this log file exceeds [maxLogSize], current log file will be closed
  /// and new one will be created with updateCurrentLogFile method
  @visibleForTesting
  late File currentLogFile;

  /// The index of the current log file.
  /// Will be incremented on every update of currentLogFile.
  @visibleForTesting
  int currentLogIndex = 0;

  @override
  bool supportLevel(BDLevel level) => level >= minimumSupportedLevel;

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    writer ??= initializeFileSink(logFileDirectory);

    assert(writer != null, 'sink should not be null here');

    final double currentFileSizeInMB =
        currentLogFile.lengthSync() / (1024 * 1024);

    if (currentFileSizeInMB >= maxLogSize) {
      writer?.flushSync();
      writer?.closeSync();
      currentLogIndex++;
      writer = updateCurrentLogFile(logFileDirectory);
      assert(writer != null, 'sink should not be null here');
    }

    writer?.writeStringSync(logFormatter.format(record));
  }

  @override
  Future<void> clean() async {
    writer?.flushSync();
    writer?.closeSync();
    writer = null;
  }

  /// Create log file to written to.
  ///
  /// The log file will be saved into the [logDir].
  ///
  /// Throws [AssertionError] if [logDir] does not exist.
  @visibleForTesting
  RandomAccessFile initializeFileSink(final Directory logDir) {
    assert(
      logDir.existsSync(),
      'Log directory does not exist',
    );

    final List<File> logFiles = getLogFiles();

    currentLogIndex = getLatestLogFileIndex(logFiles);

    return updateCurrentLogFile(logDir);
  }

  /// Get all the log files currently available in [logFileDirectory].
  ///
  /// note: only files with same [logNamePrefix] will be returned.
  @visibleForTesting
  List<File> getLogFiles() {
    final List<File> logFiles = <File>[];

    final List<FileSystemEntity> dirContent = logFileDirectory.listSync(
      followLinks: false,
    );

    for (final File file in dirContent.whereType<File>()) {
      final String fileName = path.basenameWithoutExtension(file.path);

      if (fileName.startsWith(logNamePrefix)) {
        final int fileIndex = getLogFileIndex(fileName);

        if (fileIndex >= 0) {
          logFiles.add(file);
        }
      }
    }

    return logFiles;
  }

  /// Updates current log file with a newly created one
  @visibleForTesting
  RandomAccessFile updateCurrentLogFile(Directory logDir) {
    final String fileName =
        '$logNamePrefix$logFileNameSuffix$currentLogIndex.log';

    currentLogFile = File(path.join(logDir.path, fileName));

    return currentLogFile.openSync(mode: FileMode.writeOnlyAppend);
  }

  /// Sort the list of log files by their log indexes.
  ///
  /// The files are ordered in such way that the higher log index is the latest.
  @visibleForTesting
  List<File> sortFileByIndex(final List<File> logFiles) {
    logFiles.sort((File leftFile, File rightFile) {
      final int leftFileIndex = getLogFileIndex(
        path.basenameWithoutExtension(leftFile.path),
      );

      final int rightFileIndex = getLogFileIndex(
        path.basenameWithoutExtension(rightFile.path),
      );

      // If the result is 0 then they are equal
      // If the result is lower to 0 then left is lower than right
      // If the result is greater to 0 then left is greater than right.
      return rightFileIndex - leftFileIndex;
    });

    return logFiles;
  }

  /// Get the index of the log file from the [fileName].
  ///
  /// Returns the log file index [int] or 0 if index not founded.
  @visibleForTesting
  int getLogFileIndex(final String fileName) {
    final int logSuffixIndex = fileName.lastIndexOf(logFileNameSuffix);

    if (logSuffixIndex < 0) {
      // if the last index is less than 0 so we either have no log file or
      // we have a log file that does not match the log file naming convention
      // of this files handler. So in both these cases we start from 0.
      return 0;
    }

    final RegExp pattern = RegExp(r'(\d)+$');

    final String? foundIndex =
        pattern.firstMatch(fileName.substring(logSuffixIndex))?.group(0);

    return foundIndex != null ? int.tryParse(foundIndex) ?? 0 : 0;
  }

  /// Get latest log file index from [logFiles].
  ///
  /// Returns latest log file index or 0 if not index could be found.
  @visibleForTesting
  int getLatestLogFileIndex(List<File> logFiles) {
    if (logFiles.isEmpty) {
      return 0;
    } else {
      final List<File> orderedLogFiles = sortFileByIndex(logFiles);

      final File latestLogFile = orderedLogFiles[0];

      final int latestLogFileIndex = getLogFileIndex(
        path.basenameWithoutExtension(latestLogFile.path),
      );

      return latestLogFileIndex;
    }
  }
}
