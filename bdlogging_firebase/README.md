**bdlogging_firebase** is a package that provide **BDLogHandler** for firebase services.

# Example

```dart
import 'package:bdlogging_firebase/bdlogging_firebase.dart';

final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;

final FirebaseCrashlyticsLogHandler handler = FirebaseCrashlyticsLogHandler(
    crashlytics: crashlytics,
    supportedLevels: <BDLevel>[BDLevel.warning],
);
```
