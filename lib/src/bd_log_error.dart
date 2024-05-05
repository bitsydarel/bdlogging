/// A class that represent an error that occurred during logging.
class BDLogError {
  /// The exception that occurred during logging.
  final Object exception;

  /// The stack trace of the exception that occurred during logging.
  final StackTrace stackTrace;

  /// Create a new instance of [BDLogError].
  BDLogError(this.exception, this.stackTrace);
}
