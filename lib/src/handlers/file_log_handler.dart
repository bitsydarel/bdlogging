import 'dart:io';
import 'dart:isolate';

import 'package:bdlogging/src/bd_cleanable_log_handler.dart';
import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_formatter.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:bdlogging/src/formatters/default_log_formatter.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

/// `FileLogHandler` is a class that extends `BDCleanableLogHandler`.
/// It is designed to handle logging records
/// [BDLogRecord] by writing them to files.
///
/// The class is initialized with several parameters,
/// including [logNamePrefix], [maxLogSizeInMb],
/// [maxFilesCount], [logFileDirectory], [supportedLevels], and [logFormatter].
/// These parameters are used to control the behavior of the log handler.
///
/// The [handleRecord] method is used to write
/// a [BDLogRecord] to the current log file.
///
/// If the current log file exceeds the maximum size [maxLogSizeInMb],
/// it closes the current log file and creates a new one.
///
/// The `onFileExceededMaxSize` method is called when
/// the current log file exceeds the maximum size.
///
/// It flushes and closes the current file, increments the
/// current log file index, and updates the current log file.
///
/// The [removeOldLogFilesIfRequired] method is used to remove old log files if
/// the current count of log files exceeds
/// the maximum files count [maxFilesCount].
///
/// The [initializeFileSink] method is used to create a
/// new log file in the specified directory (`logDir`).
///
/// The [updateCurrentLogFile] method is used to update
/// the current log file with a newly created one.
///
/// The [getLogFileIndex] and [getLatestLogFileIndex] methods
/// are used to get the index of a log file
/// and the latest log file index, respectively.
class FileLogHandler extends BDCleanableLogHandler {
  /// Create a new instance of [FileLogHandler].
  ///
  /// [logNamePrefix] will be used as prefix
  /// for each log file created by the instance of this [FileLogHandler].
  /// It's recommended that the [logNamePrefix] be unique in the app.
  ///
  /// [maxLogSizeInMb] in MB will be used as the maximum size of each
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
  /// [supportedLevels] will be used to discard [BDLogRecord] with
  /// [BDLevel] lower than [supportedLevels].
  FileLogHandler({
    required this.logNamePrefix,
    required this.maxLogSizeInMb,
    required this.maxFilesCount,
    required this.logFileDirectory,
    this.supportedLevels = const <BDLevel>[
      BDLevel.warning,
      BDLevel.success,
      BDLevel.error,
    ],
    this.logFormatter = const DefaultLogFormatter(),
  })  : assert(
          logNamePrefix.isNotEmpty,
          'logNamePrefix should not be empty',
        ),
        assert(
          maxLogSizeInMb > 0,
          'maxLogSizeInMb should not be lower than zero',
        );

  /// Prefix of each log files created by this [FileLogHandler].
  final String logNamePrefix;

  /// Maximum size of a log file in MB.
  final int maxLogSizeInMb;

  /// Maximum count of files to keep.
  ///
  /// will be used to deleted old log files.
  /// If in the [logFileDirectory] there's files with prefix [logNamePrefix]
  /// and the count of files is greater than [maxFilesCount],
  /// older files will be deleted.
  final int maxFilesCount;

  /// Directory where to store the log files.
  final Directory logFileDirectory;

  /// Supported [BDLevel] of [BDLogRecord].
  final List<BDLevel> supportedLevels;

  /// [BDLogFormatter] that define how [BDLogRecord] should be written.
  final BDLogFormatter logFormatter;

  /// The suffix added after the [logNamePrefix] followed by the log file index.
  @visibleForTesting
  static const String logFileNameSuffix = '_log';

  /// The writer to perform operations on the [currentLogFile]
  @visibleForTesting
  RandomAccessFile? writer;

  /// The current log file that logs are written to.
  /// If this log file exceeds [maxLogSizeInMb], current log file will be closed
  /// and new one will be created with updateCurrentLogFile method
  @visibleForTesting
  late File currentLogFile;

  /// The index of the current log file.
  /// Will be incremented on every update of currentLogFile.
  @visibleForTesting
  int currentLogIndex = 0;

  @override
  bool supportLevel(BDLevel level) => supportedLevels.contains(level);

  @override
  Future<void> handleRecord(BDLogRecord record) async {
    print("current isolate: ${Isolate.current.debugName}");
    writer ??= initializeFileSink(logFileDirectory);

    assert(writer != null, 'sink should not be null here');

    final double currentFileSizeInMB =
        currentLogFile.lengthSync() / (1024 * 1024);

    if (currentFileSizeInMB >= maxLogSizeInMb) {
      onFileExceededMaxSize();

      removeOldLogFilesIfRequired();
    }

    writer?.writeStringSync(logFormatter.format(record));
  }

  /// Called when the current log file exceeded [maxLogSizeInMb].
  @visibleForTesting
  void onFileExceededMaxSize() {
    writer?.flushSync();
    writer?.closeSync();

    currentLogIndex++;

    writer = updateCurrentLogFile(logFileDirectory);
    assert(writer != null, 'sink should not be null here');
  }

  /// Remove the old log files if the current count of log files exceed the
  /// number of log files.
  @visibleForTesting
  void removeOldLogFilesIfRequired() {
    final List<File> sortedLogFiles = getLogFiles().sortedBy<num>((File file) {
      final String fileName = path.basenameWithoutExtension(file.path);

      return getLogFileIndex(fileName);
    });

    final int filesToRemove = sortedLogFiles.length - maxFilesCount;

    // if we already exceeded the max files count allowed.
    // we delete the oldest.
    if (filesToRemove > 0) {
      sortedLogFiles.sublist(0, filesToRemove).forEach((File oldFile) {
        oldFile.deleteSync();
      });
    }
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
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }

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
