import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/club_contact.dart';

class ClubContactStore {
  static const _k = 'lions_club_contacts_v1';
  static List<ClubContact> _cache = [];
  static bool _loaded = false;

  static List<ClubContact> get current {
    final list = List<ClubContact>.of(_cache)
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return List.unmodifiable(list);
  }

  static Future<List<ClubContact>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null || raw.isEmpty) {
      _cache = [];
      _loaded = true;
      return current;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final rawCount = list.length;
      _cache = list
          .whereType<Map>()
          .map((e) => ClubContact.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty && e.isSane)
          .toList();
      _loaded = true;
      // Persist cleanup when old PDF junk rows were dropped.
      if (_cache.length != rawCount) {
        await _persist();
      }
    } catch (_) {
      _cache = [];
      _loaded = true;
    }
    return current;
  }

  /// Clear corrupted PDF import rows (keeps only sane contacts).
  static Future<int> purgeGarbage() async {
    await ensureLoaded();
    final before = _cache.length;
    _cache = _cache.where((e) => e.isSane).toList();
    if (_cache.length != before) await _persist();
    return before - _cache.length;
  }

  static Future<List<ClubContact>> ensureLoaded() async {
    if (_loaded) return current;
    return load();
  }

  static Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(_cache.map((e) => e.toJson()).toList()));
  }

  static String newId() => 'cc_${DateTime.now().microsecondsSinceEpoch}';

  static Future<void> upsert(ClubContact c) async {
    await ensureLoaded();
    if (!c.isSane) return;
    final i = _cache.indexWhere((e) => e.id == c.id);
    if (i >= 0) {
      _cache[i] = c;
    } else {
      _cache = [..._cache, c];
    }
    await _persist();
  }

  static Future<void> delete(String id) async {
    await ensureLoaded();
    _cache = _cache.where((e) => e.id != id).toList();
    await _persist();
  }

  static Future<int> replaceAll(List<ClubContact> list) async {
    _cache = list.where((e) => e.isSane).toList();
    _loaded = true;
    await _persist();
    return _cache.length;
  }

  static Future<int> mergeImported(List<ClubContact> incoming) async {
    await ensureLoaded();
    var added = 0;
    for (final c in incoming.where((e) => e.isSane)) {
      final key = _key(c);
      final i = _cache.indexWhere((e) => _key(e) == key);
      if (i >= 0) {
        final old = _cache[i];
        _cache[i] = c.copyWith(id: old.id);
      } else {
        _cache.add(c);
        added++;
      }
    }
    await _persist();
    return added;
  }

  static String _key(ClubContact c) {
    final phone = c.phone.replaceAll(RegExp(r'\D'), '');
    if (phone.isNotEmpty) return 'p:$phone';
    return 'n:${c.name.trim().toLowerCase()}|${c.clubName.trim().toLowerCase()}';
  }

  /// Unique club names (sorted) for selector.
  static List<String> get clubNames {
    final set = <String>{};
    for (final c in _cache) {
      final n = c.clubName.trim();
      if (n.isNotEmpty) set.add(n);
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static List<ClubContact> forClub(String clubName) {
    final key = clubName.trim().toLowerCase();
    if (key.isEmpty) return current;
    return current
        .where((c) => c.clubName.trim().toLowerCase() == key)
        .toList();
  }
}
