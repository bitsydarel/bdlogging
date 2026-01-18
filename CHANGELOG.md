## 1.4.0

* Added `EncryptedIsolateFileLogHandler` for encrypting sensitive data in log messages (passwords, tokens, emails, phone numbers).
* Added `SensitiveDataEncryptor` interface with `AesGcmSensitiveDataEncryptor` implementation using AES-GCM encryption.
* Added `SensitiveDataMatcher` interface with `RegexSensitiveDataMatcher` for customizable sensitive data detection patterns.
* Added configurable encryption failure handlers: `PlaintextFallbackHandler`, `MarkerFallbackHandler`, `RedactFallbackHandler`.
* Added browser-based decryption tool at `scripts/aes-gcm/decrypt.html` for QA/support staff.
* Added security warnings in documentation about error objects not being encrypted.
* Improved `BDLogger` destroy flow with `_isDestroying` flag to prevent log dropping during shutdown.
* Improved log processing race condition handling.

## 1.3.3

* Fixed race condition in `clean()` method where concurrent calls could cause callers to wait forever.
* Fixed `LateInitializationError` when log records arrive before worker initialization.
* Fixed ReceivePort resource leaks in both main and worker isolates.
* Fixed redundant `ErrorController` double-close in `destroy()`.
* Fixed `BDLogRecord` assertion for `isFatal` flag to properly require an error.
* Added `maxFilesCount > 0` validation to prevent immediate log file deletion.
* Improved `DateFormat` performance by caching instance as static final.
* Improved `BDLogRecord.hashCode` using `Object.hash()` for fewer collisions.
* Added `const` constructor to `BDLogError` for performance.
* Fixed log record ordering by awaiting `handleRecord` in worker.
* Added comprehensive regression tests for all fixes.

## 1.3.2

* Fixed bug in IsolateFileLogHandler where success and error log levels were not being written to file.
* Refactored handlePortMessage into focused methods following Single Responsibility Principle.

## 1.3.1

* Fixed potential race condition in IsolateFileLogHandler with Completer guards.
* Improved IsolateFileLogHandler testability with dependency injection for logging.
* Added comprehensive test coverage for log handlers.
* Fixed ANSI escape sequence handling in ConsoleLogHandler tests.

## 1.3.0

* Added support for Dart SDK constraint to ^3.6.0.
* Updated dependencies to the latest versions that support at Dart SDK version greater than 3.0.0.

## 1.2.0

* Added error handling in isolate file log handler.
* Added auto-creation of log directory if it does not exist in file log handler.
* Made dart 3.5.0 as minimum required version.

## 1.1.3

* Improvement over previous version, by using a new list instead of a unmodifiable version.

## 1.1.2

* Fixed issue with handlers list being modified while processioning logs.

## 1.1.1

* Fixed issue when recordQueue is empty, while processing logs.

## 1.1.0

* Changed the processing of logs, to fix logs getting lost
* Removed processing interval interface.

## 1.0.0

* Updated the package to support dart 3.0.0.
* Fixed issue with lost of events or wrong order of log events.
* Fixed console logger because it was missing some events.

## 0.1.5

* added IsolateFileLogHandler debugName to match the logNamePrefix.

## 0.1.4

* Exported Isolate File Log Handler.

## 0.1.3

* Updated log formatter for fatal exception.

## 0.1.2

* Expose the isFatal flag in the log methods.

## 0.1.1

* Updated package dependencies constraints.

## 0.1.0

* Added support for dart 3.0.0
* Added Isolate file handler, that logs into a file but in another isolate.
* Added a new BDLevel as success for success messages.

## 0.0.2

* Decreased dependency boundaries on package collection.

## 0.0.1

* Provide the functionality to log events.
* Provide two out-of-the-box log handler (console, file).
* Provide the feature of formatting logs that allow to format a log record to a pleasant format.
* Provide a default log formatter.