/// An Logging Level of importance of a log message.
enum BDLevel implements Comparable<BDLevel> {
  /// DEBUG logging level for debugging messages.
  debug('DEBUG', 3),

  /// INFO logging level for informational messages.
  info('INFO', 4),

  /// WARNING logging level for potential problems.
  warning('WARNING', 5),

  /// SUCCESS logging level for positive messages.
  success('SUCCESS', 6),

  /// ERROR logging level for server problems
  error('ERROR', 7);

  /// Create a new level with [label] and [importance].
  const BDLevel(this.label, this.importance);

  /// Name of the logging level.
  final String label;

  /// The value of the logging level, that allow it be ordered by importance
  /// or to remove logging level lower or higher to the logging level.
  final int importance;

  @override
  int compareTo(BDLevel other) => importance.compareTo(other.importance);

  @override
  String toString() => 'BDLevel{label: $label, importance: $importance}';

  /// Compare if the current [BDLevel] is greater than [other]
  bool operator >(BDLevel other) => importance > other.importance;

  /// Compare if the current [BDLevel] is greater or equal to [other]
  bool operator >=(BDLevel other) => importance >= other.importance;

  /// Compare if the current [BDLevel] is lower than [other]
  bool operator <(BDLevel other) => importance < other.importance;

  /// Compare if the current [BDLevel] is lower or equal to [other]
  bool operator <=(BDLevel other) => importance <= other.importance;
}
