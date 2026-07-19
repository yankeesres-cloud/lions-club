import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/planned_program.dart';

class PlannerStore {
  static const _kPrograms = 'lions_planner_v1';

  static List<PlannedProgram> _cache = [];
  static bool _loaded = false;

  static List<PlannedProgram> get current {
    final list = List<PlannedProgram>.of(_cache);
    list.sort((a, b) {
      final da = a.expectedDateTimeWithTime ?? a.expectedDateTime;
      final db = b.expectedDateTimeWithTime ?? b.expectedDateTime;
      if (da == null && db == null) return a.title.compareTo(b.title);
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return List.unmodifiable(list);
  }

  static List<PlannedProgram> get upcoming =>
      current.where((p) => p.isUpcoming).toList();

  static List<PlannedProgram> get reminderActive =>
      current.where((p) => p.isInReminderWindow).toList();

  static Future<List<PlannedProgram>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPrograms);
    if (raw == null || raw.trim().isEmpty) {
      _cache = [];
      _loaded = true;
      return current;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _cache = list
          .whereType<Map>()
          .map((e) => PlannedProgram.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty && e.title.trim().isNotEmpty)
          .toList();
    } catch (_) {
      _cache = [];
    }
    _loaded = true;
    return current;
  }

  static Future<List<PlannedProgram>> ensureLoaded() async {
    if (_loaded) return current;
    return load();
  }

  static Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kPrograms,
      jsonEncode(_cache.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> upsert(PlannedProgram program) async {
    await ensureLoaded();
    var prog = program;
    if (prog.checklist.isEmpty) {
      prog = prog.copyWith(checklist: PlannedProgram.defaultChecklist());
    }
    final i = _cache.indexWhere((e) => e.id == prog.id);
    if (i >= 0) {
      _cache[i] = prog;
    } else {
      _cache = [..._cache, prog];
    }
    await _persist();
  }

  static Future<void> delete(String id) async {
    await ensureLoaded();
    _cache = _cache.where((e) => e.id != id).toList();
    await _persist();
  }

  static Future<void> updateChecklist(
    String programId,
    List<ProgramChecklistItem> checklist,
  ) async {
    await ensureLoaded();
    final i = _cache.indexWhere((e) => e.id == programId);
    if (i < 0) return;
    _cache[i] = _cache[i].copyWith(checklist: checklist);
    await _persist();
  }

  static Future<void> clearPcEverywhere(String memberId) async {
    await ensureLoaded();
    var changed = false;
    _cache = _cache.map((e) {
      var next = e;
      final pcs = e.pcsNormalized.where((id) => id != memberId).toList();
      if (pcs.length != e.pcsNormalized.length) {
        changed = true;
        next = next.copyWith(pcMemberIds: pcs);
      }
      if (e.directorMemberId == memberId) {
        changed = true;
        next = next.copyWith(clearDirector: true);
      }
      return next;
    }).toList();
    if (changed) await _persist();
  }

  static Future<int> mergeImported(List<PlannedProgram> incoming) async {
    await ensureLoaded();
    var added = 0;
    for (final p in incoming.where((e) => e.title.trim().isNotEmpty)) {
      final key = _key(p);
      final i = _cache.indexWhere((e) => _key(e) == key);
      if (i >= 0) {
        final old = _cache[i];
        _cache[i] = p.copyWith(
          id: old.id,
          checklist: old.checklist.isNotEmpty ? old.checklist : p.checklist,
        );
      } else {
        _cache.add(p);
        added++;
      }
    }
    await _persist();
    return added;
  }

  static Future<int> replaceAll(List<PlannedProgram> list) async {
    _cache = list.where((e) => e.title.trim().isNotEmpty).toList();
    _loaded = true;
    await _persist();
    return _cache.length;
  }

  static String _key(PlannedProgram p) {
    final t = p.title.trim().toLowerCase();
    final m = p.resolvedMonth;
    final y = p.resolvedYear;
    final d = p.expectedDate.trim();
    return '$y|$m|$t|$d';
  }

  static String newId() => 'prog_${DateTime.now().microsecondsSinceEpoch}';
}
