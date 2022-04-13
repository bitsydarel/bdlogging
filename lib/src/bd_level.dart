import 'package:flutter/foundation.dart';

/// An Logging Level of importance of a log message.
@immutable
class BDLevel implements Comparable<BDLevel> {
  /// Create a new level with [name] and [importance].
  const BDLevel(this.name, this.importance);

  /// Name of the logging level.
  final String name;

  /// The value of the logging level, that allow it be ordered by importance
  /// or to remove logging level lower or higher to the logging level.
  final int importance;

  /// DEBUG logging level for debugging messages
  static const BDLevel debug = BDLevel('DEBUG', 3);

  /// INFO logging level for informational messages
  static const BDLevel info = BDLevel('INFO', 4);

  /// WARNING logging level for potential problems
  static const BDLevel warning = BDLevel('WARNING', 5);

  /// ERROR logging level for server problems
  static const BDLevel error = BDLevel('ERROR', 6);

  /// List of all the levels currently supported [BDLevel].
  static const List<BDLevel> levels = <BDLevel>[debug, info, warning, error];

  @override
  int compareTo(BDLevel other) => importance - other.importance;

  @override
  String toString() => 'Level{name: $name, importance: $importance}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BDLevel &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          importance == other.importance;

  @override
  int get hashCode => name.hashCode ^ importance.hashCode;

  /// Compare if the current [BDLevel] is greater than [other]
  bool operator >(BDLevel other) => importance > other.importance;

  /// Compare if the current [BDLevel] is greater or equal to [other]
  bool operator >=(BDLevel other) => importance >= other.importance;

  /// Compare if the current [BDLevel] is lower than [other]
  bool operator <(BDLevel other) => importance < other.importance;

  /// Compare if the current [BDLevel] is lower or equal to [other]
  bool operator <=(BDLevel other) => importance <= other.importance;
}
