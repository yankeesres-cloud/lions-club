import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/member.dart';
import 'board_store.dart';
import 'planner_store.dart';

class MemberStore {
  static const _kMembersV2 = 'lions_members_v2';
  static const _kMembersV1 = 'lions_members_v1';

  static List<Member> _cache = [];
  static bool _loaded = false;

  static List<Member> get current => List.unmodifiable(_cache);

  static Future<List<Member>> load() async {
    final p = await SharedPreferences.getInstance();
    final rawV2 = p.getString(_kMembersV2);
    if (rawV2 != null && rawV2.trim().isNotEmpty) {
      _cache = _decodeV2(rawV2);
      _loaded = true;
      await repairSpouseLinks();
      await relinkOrphanCouples();
      return current;
    }

    // Migrate legacy couple-rows → individual members.
    final rawV1 = p.getString(_kMembersV1);
    if (rawV1 != null && rawV1.trim().isNotEmpty) {
      _cache = _migrateV1(rawV1);
      _loaded = true;
      await repairSpouseLinks();
      await relinkOrphanCouples();
      return current;
    }

    _cache = [];
    _loaded = true;
    return current;
  }

  static List<Member> _decodeV2(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => Member.fromJson(Map<String, dynamic>.from(e)))
          .where((m) => m.id.isNotEmpty && m.isSane)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<Member> _migrateV1(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final out = <Member>[];
      for (final item in list.whereType<Map>()) {
        final j = Map<String, dynamic>.from(item);
        final hasLegacyPair = j.containsKey('nameM') || j.containsKey('nameF');
        if (hasLegacyPair) {
          final nameM = (j['nameM'] ?? '').toString().trim();
          final nameF = (j['nameF'] ?? '').toString().trim();
          if (nameM.isNotEmpty && nameF.isNotEmpty) {
            out.addAll(Member.fromLegacyCoupleRow(j));
          } else {
            final one = Member.fromJson(j);
            if (one.isSane) out.add(one.copyWith());
          }
        } else {
          final one = Member.fromJson(j);
          if (one.isSane) out.add(one);
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<List<Member>> ensureLoaded() async {
    if (_loaded) return current;
    return load();
  }

  /// Force reload + couple relink (Members screen se).
  static Future<int> reloadAndRelinkCouples() async {
    _loaded = false;
    await load();
    return current.where((m) => m.membershipType == MembershipType.couple).length;
  }

  static Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kMembersV2,
      jsonEncode(_cache.map((m) => m.toJson()).toList()),
    );
  }

  static Future<void> upsert(Member member) async {
    await ensureLoaded();
    if (!member.isSane) return;
    var safe = member;
    if (safe.spouseId == safe.id) {
      safe = safe.copyWith(
        clearSpouse: true,
        membershipType: MembershipType.single,
      );
    }
    final i = _cache.indexWhere((m) => m.id == safe.id);
    if (i >= 0) {
      _cache[i] = safe;
    } else {
      _cache = [..._cache, safe];
    }
    if (safe.hasSpouse) {
      final si = _cache.indexWhere((m) => m.id == safe.spouseId);
      if (si >= 0) {
        final spouse = _cache[si];
        if (spouse.spouseId != safe.id ||
            spouse.membershipType != MembershipType.couple) {
          _cache[si] = spouse.copyWith(
            spouseId: safe.id,
            membershipType: MembershipType.couple,
          );
        }
      }
    }
    await _persist();
  }

  static Future<void> linkSpouses(String aId, String bId) async {
    await ensureLoaded();
    if (aId.trim().isEmpty || bId.trim().isEmpty || aId == bId) return;
    final ia = _cache.indexWhere((m) => m.id == aId);
    final ib = _cache.indexWhere((m) => m.id == bId);
    if (ia < 0 || ib < 0) return;
    _cache[ia] = _cache[ia].copyWith(
      spouseId: bId,
      membershipType: MembershipType.couple,
    );
    _cache[ib] = _cache[ib].copyWith(
      spouseId: aId,
      membershipType: MembershipType.couple,
    );
    await _persist();
  }

  static Future<void> unlinkSpouse(String id) async {
    await ensureLoaded();
    final i = _cache.indexWhere((m) => m.id == id);
    if (i < 0) return;
    final spouseId = _cache[i].spouseId;
    _cache[i] = _cache[i].copyWith(
      clearSpouse: true,
      membershipType: MembershipType.single,
    );
    if (spouseId.isNotEmpty) {
      final si = _cache.indexWhere((m) => m.id == spouseId);
      if (si >= 0) {
        _cache[si] = _cache[si].copyWith(
          clearSpouse: true,
          membershipType: MembershipType.single,
        );
      }
    }
    await _persist();
  }

  static Future<void> delete(String id) async {
    await ensureLoaded();
    await unlinkSpouse(id);
    _cache = _cache.where((m) => m.id != id).toList();
    await _persist();
    await BoardStore.clearMemberEverywhere(id);
    await PlannerStore.clearPcEverywhere(id);
  }

  static Future<int> replaceAll(List<Member> members) async {
    _cache = members
        .where((m) => m.isSane)
        .map(
          (m) => m.spouseId == m.id
              ? m.copyWith(
                  clearSpouse: true,
                  membershipType: MembershipType.single,
                )
              : m,
        )
        .toList();
    _loaded = true;
    await repairSpouseLinks();
    await relinkOrphanCouples();
    return _cache.length;
  }

  /// Merge import with stable IDs + correct spouse remapping.
  static Future<int> mergeImported(List<Member> incoming) async {
    await ensureLoaded();
    final idMap = <String, String>{};
    var added = 0;

    for (final m in incoming.where((m) => m.isSane)) {
      final key = _dedupeKey(m);
      final existing = _cache.indexWhere((e) => _dedupeKey(e) == key);
      if (existing >= 0) {
        final old = _cache[existing];
        idMap[m.id] = old.id;
        _cache[existing] = m.copyWith(
          id: old.id,
          clearSpouse: true,
          membershipType: MembershipType.single,
          proposer: m.proposer.trim().isNotEmpty ? m.proposer : old.proposer,
          address: m.address.trim().isNotEmpty ? m.address : old.address,
          photo: m.photo.trim().isNotEmpty ? m.photo : old.photo,
          anniversary: m.anniversary.trim().isNotEmpty
              ? m.anniversary
              : old.anniversary,
        );
      } else {
        idMap[m.id] = m.id;
        _cache.add(
          m.copyWith(
            clearSpouse: true,
            membershipType: MembershipType.single,
          ),
        );
        added++;
      }
    }

    final linked = <String>{};
    for (final m in incoming.where((x) => x.isSane && x.hasSpouse)) {
      final selfId = idMap[m.id];
      final spouseStoredId = idMap[m.spouseId];
      if (selfId == null || spouseStoredId == null || selfId == spouseStoredId) {
        continue;
      }
      final pair = [selfId, spouseStoredId]..sort();
      final pk = '${pair[0]}|${pair[1]}';
      if (linked.contains(pk)) continue;
      linked.add(pk);
      await linkSpouses(selfId, spouseStoredId);
    }

    await repairSpouseLinks();
    await relinkOrphanCouples();
    return added;
  }

  static Future<void> repairSpouseLinks() async {
    if (!_loaded) return;
    var changed = false;
    for (var i = 0; i < _cache.length; i++) {
      final m = _cache[i];
      if (!m.hasSpouse) continue;
      if (m.spouseId == m.id) {
        _cache[i] = m.copyWith(
          clearSpouse: true,
          membershipType: MembershipType.single,
        );
        changed = true;
        continue;
      }
      final spouse = byId(m.spouseId);
      if (spouse == null) {
        _cache[i] = m.copyWith(
          clearSpouse: true,
          membershipType: MembershipType.single,
        );
        changed = true;
      }
    }
    for (var i = 0; i < _cache.length; i++) {
      final m = _cache[i];
      if (!m.hasSpouse || m.spouseId == m.id) continue;
      final si = _cache.indexWhere((e) => e.id == m.spouseId);
      if (si < 0) continue;
      final spouse = _cache[si];
      if (spouse.spouseId != m.id ||
          m.membershipType != MembershipType.couple ||
          spouse.membershipType != MembershipType.couple) {
        _cache[i] = m.copyWith(
          spouseId: spouse.id,
          membershipType: MembershipType.couple,
        );
        _cache[si] = spouse.copyWith(
          spouseId: m.id,
          membershipType: MembershipType.couple,
        );
        changed = true;
      }
    }
    if (changed) await _persist();
  }

  /// Excel couples jo single ban gaye — phone / anniversary / id se dubara jodo.
  static Future<int> relinkOrphanCouples() async {
    if (!_loaded) return 0;
    final used = <String>{};
    for (final m in _cache) {
      if (!m.hasSpouse || m.spouseId == m.id) continue;
      if (byId(m.spouseId) == null) continue;
      used.add(m.id);
      used.add(m.spouseId);
    }

    var pairs = 0;

    bool tryLink(Member a, Member b) {
      if (a.id == b.id) return false;
      if (used.contains(a.id) || used.contains(b.id)) return false;
      if (a.gender == b.gender) return false;
      final ia = _cache.indexWhere((e) => e.id == a.id);
      final ib = _cache.indexWhere((e) => e.id == b.id);
      if (ia < 0 || ib < 0) return false;
      _cache[ia] = _cache[ia].copyWith(
        spouseId: b.id,
        membershipType: MembershipType.couple,
      );
      _cache[ib] = _cache[ib].copyWith(
        spouseId: a.id,
        membershipType: MembershipType.couple,
      );
      used.add(a.id);
      used.add(b.id);
      pairs++;
      return true;
    }

    final byBase = <String, List<Member>>{};
    for (final m in _cache) {
      if (used.contains(m.id)) continue;
      final id = m.id;
      String? base;
      if (id.endsWith('_m') || id.endsWith('_M')) {
        base = id.substring(0, id.length - 2);
      } else if (id.endsWith('_f') || id.endsWith('_F')) {
        base = id.substring(0, id.length - 2);
      }
      if (base == null || base.isEmpty) continue;
      byBase.putIfAbsent(base, () => []).add(m);
    }
    for (final group in byBase.values) {
      Member? male;
      Member? female;
      for (final g in group) {
        if (g.gender == MemberGender.male) male = g;
        if (g.gender == MemberGender.female) female = g;
      }
      if (male != null && female != null) tryLink(male, female);
    }

    final byPhone = <String, List<Member>>{};
    for (final m in _cache) {
      if (used.contains(m.id)) continue;
      final phone = m.phone.replaceAll(RegExp(r'\D'), '');
      if (phone.length < 8) continue;
      byPhone.putIfAbsent(phone, () => []).add(m);
    }
    for (final group in byPhone.values) {
      final males = group.where((e) => e.gender == MemberGender.male).toList();
      final females =
          group.where((e) => e.gender == MemberGender.female).toList();
      if (males.length == 1 && females.length == 1) {
        tryLink(males.first, females.first);
      }
    }

    final byAnn = <String, List<Member>>{};
    for (final m in _cache) {
      if (used.contains(m.id)) continue;
      final key = _anniversaryKey(m);
      if (key.isEmpty) continue;
      byAnn.putIfAbsent(key, () => []).add(m);
    }
    for (final group in byAnn.values) {
      final males = group.where((e) => e.gender == MemberGender.male).toList();
      final females =
          group.where((e) => e.gender == MemberGender.female).toList();
      if (males.length == 1 && females.length == 1) {
        tryLink(males.first, females.first);
      }
    }

    if (pairs > 0) await _persist();
    return pairs;
  }

  static String _anniversaryKey(Member m) {
    final d = Member.parseFlexibleDate(m.anniversary);
    if (d == null) return '';
    return '${d.month}_${d.day}';
  }

  static String _dedupeKey(Member m) {
    final phone = m.phone.replaceAll(RegExp(r'\D'), '');
    if (phone.isNotEmpty) return 'p:$phone|${m.gender.name}';
    return 'n:${m.name.trim().toLowerCase()}|${m.gender.name}';
  }

  static String newId() => 'm_${DateTime.now().microsecondsSinceEpoch}';

  static const _demoMemberIds = <String>[
    'demo_narendra_singhal',
    'demo_bday_0',
    'demo_bday_1',
    'demo_bday_2',
    'demo_bday_3',
    'demo_bday_4',
    'demo_bday_5',
    'demo_ann_m_0',
    'demo_ann_f_0',
    'demo_ann_m_1',
    'demo_ann_f_1',
  ];

  /// Purane check/demo members hatao — auto-seed band; delete ke baad wapas nahi.
  static Future<int> removeOccasionCheckDemos() async {
    await ensureLoaded();
    await BoardStore.ensureLoaded();
    var removed = 0;
    for (final id in _demoMemberIds) {
      if (byId(id) == null) continue;
      await delete(id);
      removed++;
    }
    final demoPosts = BoardStore.current
        .where((p) => p.title.trim() == 'DEMO · DIRECTOR')
        .toList();
    for (final p in demoPosts) {
      await BoardStore.deletePost(p.id);
    }
    return removed;
  }

  static Member? byId(String id) {
    if (id.trim().isEmpty) return null;
    try {
      return _cache.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  static String? spouseDisplayName(Member m) {
    if (!m.hasSpouse || m.spouseId == m.id) return null;
    final s = byId(m.spouseId);
    if (s == null || s.id == m.id) return null;
    return s.displayName;
  }
}
