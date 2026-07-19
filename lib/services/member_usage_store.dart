import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Kitni baar app / screens open — star rating ke liye.
class MemberUsageStore {
  static const _k = 'lions_member_usage_v1';
  static Map<String, int> _opens = {};
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null || raw.isEmpty) {
      _opens = {};
      _loaded = true;
      return;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _opens = {
        for (final e in map.entries)
          e.key: (e.value is num)
              ? (e.value as num).toInt()
              : int.tryParse('${e.value}') ?? 0,
      };
    } catch (_) {
      _opens = {};
    }
    _loaded = true;
  }

  static Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(_opens));
  }

  /// Desk / module open hone par call.
  static Future<void> recordOpen(String memberId) async {
    final id = memberId.trim();
    if (id.isEmpty) return;
    await ensureLoaded();
    _opens[id] = (_opens[id] ?? 0) + 1;
    await _persist();
  }

  static int openCount(String memberId) {
    final id = memberId.trim();
    if (id.isEmpty) return 0;
    return _opens[id] ?? 0;
  }
}
