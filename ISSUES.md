# Bug Tracking - bdlogging

This document tracks identified bugs and issues in the bdlogging library.

## Summary

| Severity | Count | Fixed |
|----------|-------|-------|
| High     | 4     | 4     |
| Medium   | 4     | 4     |
| Low      | 4     | 4     |
| **Total**| **12**| **12**|

---

## High Severity Issues

### Issue 1: Race Condition in clean() - IsolateFileLogHandler
- **File:** `lib/src/handlers/isolate_file_log_handler.dart`
- **Lines:** 213-217
- **Status:** [x] Fixed
- **Description:** The `clean()` method creates a new `Completer` and assigns it to `_cleanCompleter` AFTER sending the clean command. If `clean()` is called twice in rapid succession before the first clean completes, the second call will overwrite `_cleanCompleter`, potentially causing the first caller to wait forever.

---

### Issue 2: Worker Uses Handler Before Initialization
- **File:** `lib/src/handlers/isolate_file_log_handler.dart`
- **Lines:** 265-274, 291-293
- **Status:** [x] Fixed
- **Description:** In `_FileLoggerWorker`, log records can arrive BEFORE the `_FileLogHandlerOptions` message that initializes `_fileLogHandler`. If `handleRecord()` is called before options are received, `_processRequest()` will try to use an uninitialized `_fileLogHandler`, causing a `LateInitializationError`.

---

### Issue 3: ReceivePort Never Closed in IsolateFileLogHandler
- **File:** `lib/src/handlers/isolate_file_log_handler.dart`
- **Lines:** 124-145
- **Status:** [x] Fixed
- **Description:** The `ReceivePort` created in `_startLogging()` is never closed. Even after `clean()` kills the isolate, the port remains open, which can prevent the Dart VM from exiting cleanly and causes resource leaks.

---

### Issue 4: Worker ReceivePort Never Closed
- **File:** `lib/src/handlers/isolate_file_log_handler.dart`
- **Lines:** 261-275
- **Status:** [x] Fixed
- **Description:** In `_FileLoggerWorker`, the `_receivePort` is never closed after processing the clean command. This is a resource leak.

---

## Medium Severity Issues

### Issue 5: ErrorController Closed Twice
- **File:** `lib/bdlogging.dart`
- **Lines:** 263-264
- **Status:** [x] Fixed
- **Description:** The `_errorController` is closed twice - first `sink.close()` then `close()`. While StreamController handles this gracefully, it's redundant and could mask bugs.

---

### Issue 6: BDLogRecord Assertion is Always True
- **File:** `lib/src/bd_log_record.dart`
- **Lines:** 17-22
- **Status:** [x] Fixed
- **Description:** The assertion `(isFatal && error != null) || (!isFatal && error != null) || error == null` simplifies to `true` for all inputs. The intended assertion should be `!isFatal || error != null` to ensure `isFatal` is only used with an error.

---

### Issue 7: Missing maxFilesCount Validation
- **File:** `lib/src/handlers/file_log_handler.dart` and `lib/src/handlers/isolate_file_log_handler.dart`
- **Status:** [x] Fixed
- **Description:** `maxFilesCount` is not validated. A value of 0 or negative would cause all log files to be deleted immediately.

---

### Issue 8: DateFormat Created on Every Call
- **File:** `lib/src/formatters/default_log_formatter.dart`
- **Lines:** 15-16
- **Status:** [x] Fixed
- **Description:** A new `DateFormat` instance is created for every `format()` call. This is inefficient as `DateFormat` can be reused.

---

## Low Severity Issues

### Issue 9: BDLogRecord.hashCode Uses XOR
- **File:** `lib/src/bd_log_record.dart`
- **Lines:** 55-61
- **Status:** [x] Fixed
- **Description:** Using XOR for combining hash codes is not ideal and can lead to collisions. The `Object.hash()` function is preferred in modern Dart.

---

### Issue 10: Missing const Constructor for BDLogError
- **File:** `lib/src/bd_log_error.dart`
- **Line:** 10
- **Status:** [x] Fixed
- **Description:** `BDLogError` could have a `const` constructor for better performance.

---

### Issue 11: Worker handleRecord Not Awaited
- **File:** `lib/src/handlers/isolate_file_log_handler.dart`
- **Lines:** 291-293
- **Status:** [x] Fixed
- **Description:** `_fileLogHandler.handleRecord(record)` returns a Future but it's not awaited in `_processRequest()`. This could cause log records to be processed out of order.

---

### Issue 12: Example App Creates 10 Million Logs
- **File:** `example/lib/main.dart`
- **Lines:** 52-54
- **Status:** [x] Fixed
- **Description:** The example creates 10 million log records which will consume significant memory and disk space.

---

## Change Log

| Date | Issue | Change |
|------|-------|--------|
| 2026-01-17 | Issue 1 | Fixed race condition in `clean()` by returning existing future if clean is in progress |
| 2026-01-17 | Issue 2 | Added buffering for log records until worker initialization completes |
| 2026-01-17 | Issue 3 | Fixed main isolate ReceivePort leak by closing it in `_handleCleanCompletedMessage()` |
| 2026-01-17 | Issue 4 | Fixed worker ReceivePort leak by closing it after processing clean command |
| 2026-01-17 | Issue 5 | Removed redundant `sink.close()` call in `destroy()` |
| 2026-01-17 | Issue 6 | Fixed `isFatal` assertion to `!isFatal \|\| error != null` |
| 2026-01-17 | Issue 7 | Added `maxFilesCount > 0` assertion in both file handlers |
| 2026-01-17 | Issue 8 | Made `DateFormat` a static final field for performance |
| 2026-01-17 | Issue 9 | Changed hashCode from XOR to `Object.hash()` |
| 2026-01-17 | Issue 10 | Added `const` constructor to `BDLogError` |
| 2026-01-17 | Issue 11 | Fixed worker `handleRecord` to be properly awaited |
| 2026-01-17 | Issue 12 | Reduced example app loop from 10M to 100 iterations |
