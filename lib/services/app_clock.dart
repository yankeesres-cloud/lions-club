import 'package:flutter/foundation.dart';

/// Check / demo ke liye date aage-peeche — system clock badle bina.
class AppClock {
  static final ValueNotifier<int> changes = ValueNotifier(0);
  static DateTime? _overrideDay;

  static bool get isOverridden => _overrideDay != null;

  static DateTime get now {
    final real = DateTime.now();
    final o = _overrideDay;
    if (o == null) return real;
    return DateTime(
      o.year,
      o.month,
      o.day,
      real.hour,
      real.minute,
      real.second,
      real.millisecond,
    );
  }

  static DateTime get today {
    final n = now;
    return DateTime(n.year, n.month, n.day);
  }

  static void shiftDays(int days) {
    _overrideDay = today.add(Duration(days: days));
    changes.value++;
  }

  static void resetToReal() {
    _overrideDay = null;
    changes.value++;
  }
}
