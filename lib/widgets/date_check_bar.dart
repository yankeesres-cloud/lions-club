import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/app_clock.dart';
import '../services/occasion_wall_poster.dart';

/// Demo check: date +1 / -1 — birthday / anniversary message test.
class DateCheckBar extends StatelessWidget {
  const DateCheckBar({
    super.key,
    this.onDateChanged,
  });

  final Future<void> Function()? onDateChanged;

  Future<void> _shift(int days) async {
    AppClock.shiftDays(days);
    await onDateChanged?.call();
  }

  Future<void> _reset() async {
    AppClock.resetToReal();
    await OccasionWallPoster.clearPostedHistory();
    await onDateChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppClock.changes,
      builder: (context, _) {
        final label = DateFormat('EEE, d MMM yyyy').format(AppClock.today);
        final tint = AppClock.isOverridden
            ? const Color(0xFFFFF3E0)
            : const Color(0xFFE8F5E9);
        return Material(
          color: tint,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Text(
                  'CHECK DATE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '-1 din',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                ),
                IconButton(
                  tooltip: '+1 din',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                ),
                TextButton(
                  onPressed: _reset,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Aaj', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
