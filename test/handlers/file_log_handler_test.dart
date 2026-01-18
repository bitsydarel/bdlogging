import 'dart:io';

import 'package:bdlogging/src/bd_level.dart';
import 'package:bdlogging/src/bd_log_record.dart';
import 'package:bdlogging/src/formatters/default_log_formatter.dart';
import 'package:bdlogging/src/handlers/file_log_handler.dart';
import 'package:mocktail/mocktail.dart' as mockito;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  final BDLogRecord logRecord = BDLogRecord(BDLevel.debug, 'text');

  late Directory directory;
  late String uniqueDirName;

  setUp(() {
    // Create a unique directory for each test to avoid conflicts
    uniqueDirName = 'file_test_${DateTime.now().microsecondsSinceEpoch}';
    directory = Directory(
      path.join(Directory.current.path, 'test/resources', uniqueDirName),
    )..createSync(recursive: true);
  });

  tearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  group('constructor', () {
    test('should throw assertion error for maxFilesCount <= 0', () {
      expect(
        () => FileLogHandler(
          logNamePrefix: 'test',
          maxLogSizeInMb: 5,
          maxFilesCount: 0,
          logFileDirectory: directory,
        ),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => FileLogHandler(
          logNamePrefix: 'test',
          maxLogSizeInMb: 5,
          maxFilesCount: -1,
          logFileDirectory: directory,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('should allow maxFilesCount greater than zero', () {
      expect(
        () => FileLogHandler(
          logNamePrefix: 'test',
          maxLogSizeInMb: 5,
          maxFilesCount: 1,
          logFileDirectory: directory,
        ),
        returnsNormally,
      );
    });
  });

  group('handleRecord', () {
    test('should call initializeFileSink if writer is null', () async {
      final FileLogHandler handler = FileLogHandler(
        logNamePrefix: 'cx4a',
        maxLogSizeInMb: 1,
        maxFilesCount: 5,
        logFileDirectory: directory,
        supportedLevels: <BDLevel>[BDLevel.error],
      );

      expect(handler.writer, isNull);

      await handler.handleRecord(logRecord);

      expect(handler.writer, isNotNull);
    });

    test('should update currentLogIndex if file exceeds maxLogSize', () async {
      final File fileMock = _FileMock();
      final RandomAccessFile writerMock = _WriterMock();

      final FileLogHandler handler = FileLogHandler(
        logNamePrefix: 'cx4a',
        maxLogSizeInMb: 1,
        maxFilesCount: 5,
        logFileDirectory: directory,
        supportedLevels: <BDLevel>[BDLevel.error],
      )
        ..writer = writerMock
        ..currentLogFile = fileMock;

      mockito.when(fileMock.lengthSync).thenReturn(1024 * 1024 * 2);

      expect(handler.currentLogIndex, equals(0));

      await handler.handleRecord(logRecord);

      expect(
        handler.currentLogIndex,
        equals(1),
      );
    });

    test(
        'should create new logFile '
        'if currentLogFile exceeds maxLogSize', () async {
      final File fileMock = _FileMock();

      final FileLogHandler handler = FileLogHandler(
        logNamePrefix: 'cx4a',
        maxLogSizeInMb: 1,
        maxFilesCount: 5,
        logFileDirectory: directory,
        supportedLevels: <BDLevel>[BDLevel.error],
      )
        ..writer = _WriterMock()
        ..currentLogFile = fileMock;

      mockito.when(fileMock.lengthSync).thenReturn(1024 * 1024 * 2);

      await handler.handleRecord(logRecord);

      expect(handler.writer, isNot(equals(fileMock)));
    });

    test(
        'should flush and close writer before creating new one '
        'if currentLogFile exceeds maxLogSize', () async {
      final File fileMock = _FileMock();
      final RandomAccessFile writerMock = _WriterMock();
      final FileLogHandler handler = FileLogHandler(
        logNamePrefix: 'cx4a',
        maxLogSizeInMb: 1,
        maxFilesCount: 5,
        logFileDirectory: directory,
        supportedLevels: <BDLevel>[BDLevel.error],
      )
        ..writer = writerMock
        ..currentLogFile = fileMock;

      mockito.when(fileMock.lengthSync).thenReturn(1024 * 1024 * 2);

      await handler.handleRecord(logRecord);

      mockito.verifyInOrder<void>(<void Function()>[
        writerMock.flushSync,
        writerMock.closeSync,
      ]);
    });

    test('should write log to the file by calling writeStringSync', () async {
      final File fileMock = _FileMock();
      final RandomAccessFile writerMock = _WriterMock();
      const DefaultLogFormatter logFormatter = DefaultLogFormatter();
      final FileLogHandler handler = FileLogHandler(
        logNamePrefix: 'cx4a',
        maxLogSizeInMb: 1,
        maxFilesCount: 5,
        logFileDirectory: directory,
        supportedLevels: <BDLevel>[BDLevel.error],
      )
        ..writer = writerMock
        ..currentLogFile = fileMock;

      mockito.when(fileMock.lengthSync).thenReturn(0);

      await handler.handleRecord(logRecord);

      mockito
          .verify(
              () => writerMock.writeStringSync(logFormatter.format(logRecord)))
          .called(1);
      mockito.verifyNoMoreInteractions(writerMock);
    });
  });

  group('getLogFileIndex', () {
    test(
      'should return the index of the file from the filename',
      () {
        final FileLogHandler handler = FileLogHandler(
          logNamePrefix: 'cx4a',
          maxLogSizeInMb: 1,
          maxFilesCount: 5,
          logFileDirectory: Directory('random'),
        );

        const String filenameSuffix = FileLogHandler.logFileNameSuffix;

        final String testFileNameWithoutIndex =
            handler.logNamePrefix + filenameSuffix;

        expect(
          handler.getLogFileIndex('${testFileNameWithoutIndex}1'),
          equals(1),
        );

        expect(
          handler.getLogFileIndex('${testFileNameWithoutIndex}10'),
          equals(10),
        );

        expect(
          handler.getLogFileIndex('${testFileNameWithoutIndex}998241'),
          equals(998241),
        );

        expect(
          handler.getLogFileIndex(
            '${testFileNameWithoutIndex}142_$filenameSuffix${filenameSuffix}12',
          ),
          equals(12),
        );
      },
    );

    test(
      'should return 0 if the log file index is not present from filename',
      () {
        final FileLogHandler handler = FileLogHandler(
          logNamePrefix: 'cx4a',
          maxLogSizeInMb: 1,
          maxFilesCount: 5,
          logFileDirectory: Directory('random'),
        );

        expect(
          handler.getLogFileIndex('asdasfassadfasdfa'),
          equals(0),
        );

        expect(
          handler.getLogFileIndex(
            handler.logNamePrefix + FileLogHandler.logFileNameSuffix,
          ),
          equals(0),
        );

        expect(
          handler.getLogFileIndex(
            '${FileLogHandler.logFileNameSuffix} '
            '122$FileLogHandler.logFileNameSuffix',
          ),
          equals(0),
        );

        expect(
          handler.getLogFileIndex('${FileLogHandler.logFileNameSuffix}123_'),
          equals(0),
        );

        expect(
          handler.getLogFileIndex('323131412432'),
          equals(0),
        );
      },
    );
  });

  group('getLatestLogFileIndex', () {
    test(
      'should return log file index 0 if there is not any previous log files',
      () {
        final FileLogHandler handler = FileLogHandler(
          logNamePrefix: 'cx4a',
          maxLogSizeInMb: 1,
          maxFilesCount: 5,
          logFileDirectory: Directory('_'),
        );

        expect(
          handler.getLatestLogFileIndex(<File>[]),
          equals(0),
        );
      },
    );

    test(
      'should return latest log file index '
      'if there is any previous ordered logs',
      () {
        final FileLogHandler handler = FileLogHandler(
          logNamePrefix: 'cx4a',
          maxLogSizeInMb: 1,
          maxFilesCount: 5,
          logFileDirectory: Directory('_'),
        );

        final String testFileName =
            handler.logNamePrefix + FileLogHandler.logFileNameSuffix;

        final File file1 = File('x/${testFileName}0.log');
        final File file2 = File('x/${testFileName}1.log');
        final File file3 = File('x/${testFileName}2.log');
        final File file4 = File('x/${testFileName}3.log');

        expect(
          handler.getLatestLogFileIndex(<File>[file4, file3, file2, file1]),
          equals(3),
        );
      },
    );
  });

  test(
    'should only log event withBDLevel equal or greater than'
    ' minimumSupportedLevel',
    () {
      final FileLogHandler handler = FileLogHandler(
        logNamePrefix: 'cx4a',
        maxLogSizeInMb: 1,
        maxFilesCount: 5,
        logFileDirectory: Directory('random'),
        supportedLevels: <BDLevel>[BDLevel.error],
      );

      expect(handler.supportLevel(BDLevel.info), isFalse);
      expect(handler.supportLevel(BDLevel.warning), isFalse);
      expect(handler.supportLevel(BDLevel.error), isTrue);
    },
  );

  test('should flush, close and delete writer when clean called', () {
    final RandomAccessFile writer = _WriterMock();

    final FileLogHandler handler = FileLogHandler(
      logNamePrefix: 'cx4a',
      maxLogSizeInMb: 1,
      maxFilesCount: 5,
      logFileDirectory: Directory('random'),
      supportedLevels: <BDLevel>[BDLevel.error],
    )..writer = writer;

    expect(handler.writer, isNotNull);

    handler.clean();

    mockito.verifyInOrder<void>(<void Function()>[
      writer.flushSync,
      writer.closeSync,
    ]);

    expect(handler.writer, isNull);
  });

  test(
    'should sort file by index in desc',
    () {
      final FileLogHandler handler = FileLogHandler(
        logNamePrefix: 'cx4a',
        maxLogSizeInMb: 1,
        maxFilesCount: 5,
        logFileDirectory: Directory('_'),
      );

      final String testFileName =
          handler.logNamePrefix + FileLogHandler.logFileNameSuffix;

      final File file1 = File('x/${testFileName}5.log');
      final File file2 = File('x/${testFileName}15.log');
      final File file3 = File('x/${testFileName}23.log');
      final File file4 = File('x/${testFileName}50.log');

      final List<File> expectedFinalResult = <File>[file4, file3, file2, file1];

      expect(
        handler.sortFileByIndex(
          <File>[file1, file2, file3, file4],
        ),
        orderedEquals(expectedFinalResult),
      );

      expect(
        handler.sortFileByIndex(
          <File>[file4, file2, file1, file3],
        ),
        orderedEquals(expectedFinalResult),
      );

      expect(
        handler.sortFileByIndex(
          <File>[file4, file3, file2, file1],
        ),
        orderedEquals(expectedFinalResult),
      );
    },
  );

  test('should update current log file', () async {
    final FileLogHandler handler = FileLogHandler(
      logNamePrefix: 'cx4a',
      maxLogSizeInMb: 1,
      maxFilesCount: 5,
      logFileDirectory: directory,
      supportedLevels: <BDLevel>[BDLevel.error],
    );

    await handler.handleRecord(logRecord);

    final File file = handler.currentLogFile;

    handler.updateCurrentLogFile(handler.logFileDirectory);

    expect(handler.currentLogFile, isNot(equals(file)));
  });

  test('should update currentLogIndex every time initializeFileSink called',
      () {
    final FileLogHandler handler = FileLogHandler(
      logNamePrefix: 'cx4a',
      maxLogSizeInMb: 1,
      maxFilesCount: 5,
      logFileDirectory: directory,
      supportedLevels: <BDLevel>[BDLevel.error],
    )..currentLogIndex = 10;

    handler.initializeFileSink(handler.logFileDirectory);

    expect(handler.currentLogIndex, equals(0));
  });

  test('should get log files ', () {
    final Directory directory = _DirectoryMock();
    final FileLogHandler handler = FileLogHandler(
      logNamePrefix: 'cx4a',
      maxLogSizeInMb: 1,
      maxFilesCount: 5,
      logFileDirectory: directory,
      supportedLevels: <BDLevel>[BDLevel.error],
    );

    mockito
        .when(() => directory.listSync(
            recursive: mockito.any(named: 'recursive'),
            followLinks: mockito.any(named: 'followLinks')))
        .thenReturn(<FileSystemEntity>[]);

    handler.getLogFiles();

    mockito
        .verify(() => directory.listSync(
            recursive: mockito.any(named: 'recursive'),
            followLinks: mockito.any(named: 'followLinks')))
        .called(1);
  });

  group('removeOldLogFilesIfRequired', () {
    test('should delete oldest files when exceeding maxFilesCount', () {
      // Create test files with different indices
      const String testFileName =
          'remove_test${FileLogHandler.logFileNameSuffix}';

      final File file0 = File(path.join(directory.path, '${testFileName}0.log'))
        ..createSync();
      final File file1 = File(path.join(directory.path, '${testFileName}1.log'))
        ..createSync();
      final File file2 = File(path.join(directory.path, '${testFileName}2.log'))
        ..createSync();
      final File file3 = File(path.join(directory.path, '${testFileName}3.log'))
        ..createSync();
      final File file4 = File(path.join(directory.path, '${testFileName}4.log'))
        ..createSync();

      FileLogHandler(
        logNamePrefix: 'remove_test',
        maxLogSizeInMb: 1,
        maxFilesCount: 3,
        logFileDirectory: directory,
      ).removeOldLogFilesIfRequired();

      // Should have deleted the 2 oldest files (file0 and file1)
      expect(file0.existsSync(), isFalse);
      expect(file1.existsSync(), isFalse);
      expect(file2.existsSync(), isTrue);
      expect(file3.existsSync(), isTrue);
      expect(file4.existsSync(), isTrue);
    });

    test('should not delete files when under maxFilesCount', () {
      const String testFileName =
          'under_limit${FileLogHandler.logFileNameSuffix}';

      final File file0 = File(path.join(directory.path, '${testFileName}0.log'))
        ..createSync();
      final File file1 = File(path.join(directory.path, '${testFileName}1.log'))
        ..createSync();

      FileLogHandler(
        logNamePrefix: 'under_limit',
        maxLogSizeInMb: 1,
        maxFilesCount: 5,
        logFileDirectory: directory,
      ).removeOldLogFilesIfRequired();

      // Both files should still exist
      expect(file0.existsSync(), isTrue);
      expect(file1.existsSync(), isTrue);
    });

    test('should not delete files when at exactly maxFilesCount', () {
      const String testFileName =
          'exact_limit${FileLogHandler.logFileNameSuffix}';

      final File file0 = File(path.join(directory.path, '${testFileName}0.log'))
        ..createSync();
      final File file1 = File(path.join(directory.path, '${testFileName}1.log'))
        ..createSync();
      final File file2 = File(path.join(directory.path, '${testFileName}2.log'))
        ..createSync();

      FileLogHandler(
        logNamePrefix: 'exact_limit',
        maxLogSizeInMb: 1,
        maxFilesCount: 3,
        logFileDirectory: directory,
      ).removeOldLogFilesIfRequired();

      // All files should still exist
      expect(file0.existsSync(), isTrue);
      expect(file1.existsSync(), isTrue);
      expect(file2.existsSync(), isTrue);
    });
  });

  group('initializeFileSink', () {
    test('should auto-create directory if it does not exist', () {
      final Directory nonExistentDir = Directory(
        path.join(directory.path, 'non_existent_subdir'),
      );

      expect(nonExistentDir.existsSync(), isFalse);

      FileLogHandler(
        logNamePrefix: 'auto_create',
        maxLogSizeInMb: 1,
        maxFilesCount: 5,
        logFileDirectory: nonExistentDir,
      ).initializeFileSink(nonExistentDir);

      expect(nonExistentDir.existsSync(), isTrue);
    });

    test('should auto-create nested directories recursively', () {
      final Directory nestedDir = Directory(
        path.join(directory.path, 'level1', 'level2', 'level3'),
      );

      expect(nestedDir.existsSync(), isFalse);

      FileLogHandler(
        logNamePrefix: 'nested_create',
        maxLogSizeInMb: 1,
        maxFilesCount: 5,
        logFileDirectory: nestedDir,
      ).initializeFileSink(nestedDir);

      expect(nestedDir.existsSync(), isTrue);
    });
  });

  group('getLogFiles', () {
    test('should return only files matching logNamePrefix', () {
      const String matchingPrefix =
          'matching${FileLogHandler.logFileNameSuffix}';
      const String otherPrefix = 'other${FileLogHandler.logFileNameSuffix}';

      // Create matching files
      File(path.join(directory.path, '${matchingPrefix}0.log')).createSync();
      File(path.join(directory.path, '${matchingPrefix}1.log')).createSync();

      // Create non-matching files
      File(path.join(directory.path, '${otherPrefix}0.log')).createSync();
      File(path.join(directory.path, 'random_file.txt')).createSync();

      final FileLogHandler handler = FileLogHandler(
        logNamePrefix: 'matching',
        maxLogSizeInMb: 1,
        maxFilesCount: 5,
        logFileDirectory: directory,
      );

      final List<File> logFiles = handler.getLogFiles();

      expect(logFiles, hasLength(2));
      expect(
        logFiles.every(
          (File f) => path.basename(f.path).startsWith('matching'),
        ),
        isTrue,
      );
    });

    test('should ignore directories in log directory', () {
      const String prefix = 'dir_test${FileLogHandler.logFileNameSuffix}';

      // Create a matching file
      File(path.join(directory.path, '${prefix}0.log')).createSync();

      // Create a directory with matching name
      Directory(path.join(directory.path, '${prefix}1')).createSync();

      final FileLogHandler handler = FileLogHandler(
        logNamePrefix: 'dir_test',
        maxLogSizeInMb: 1,
        maxFilesCount: 5,
        logFileDirectory: directory,
      );

      final List<File> logFiles = handler.getLogFiles();

      expect(logFiles, hasLength(1));
    });

    test('should return empty list when no matching files exist', () {
      // Create non-matching files only
      File(path.join(directory.path, 'other_file.log')).createSync();
      File(path.join(directory.path, 'another_file.txt')).createSync();

      final FileLogHandler handler = FileLogHandler(
        logNamePrefix: 'no_match',
        maxLogSizeInMb: 1,
        maxFilesCount: 5,
        logFileDirectory: directory,
      );

      final List<File> logFiles = handler.getLogFiles();

      expect(logFiles, isEmpty);
    });
  });
}

class _WriterMock extends mockito.Mock implements RandomAccessFile {}

class _FileMock extends mockito.Mock implements File {}

class _DirectoryMock extends mockito.Mock implements Directory {}
