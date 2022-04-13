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
