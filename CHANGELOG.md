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