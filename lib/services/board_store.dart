import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/board_post.dart';
import '../models/board_post_role_mapper.dart';
import '../models/club_role.dart';

class BoardStore {
  static const _kPosts = 'lions_board_posts_v1';

  static List<BoardPost> _cache = [];
  static bool _loaded = false;

  static List<BoardPost> get current {
    final list = List<BoardPost>.of(_cache)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return List.unmodifiable(list);
  }

  static Future<List<BoardPost>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPosts);
    if (raw == null || raw.trim().isEmpty) {
      _cache = BoardDefaults.posts();
      _loaded = true;
      await _persist();
      return current;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _cache = list
          .whereType<Map>()
          .map((e) => BoardPost.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty && e.title.trim().isNotEmpty)
          .toList();
      if (_cache.isEmpty) {
        _cache = BoardDefaults.posts();
        await _persist();
      }
    } catch (_) {
      _cache = BoardDefaults.posts();
      await _persist();
    }
    _loaded = true;
    return current;
  }

  static Future<List<BoardPost>> ensureLoaded() async {
    if (_loaded) return current;
    return load();
  }

  static Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kPosts,
      jsonEncode(_cache.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> upsert(BoardPost post) async {
    await ensureLoaded();
    final i = _cache.indexWhere((e) => e.id == post.id);
    if (i >= 0) {
      _cache[i] = post;
    } else {
      _cache = [..._cache, post];
    }
    await _persist();
  }

  static Future<void> assignMember({
    required String postId,
    required String memberId,
  }) async {
    await ensureLoaded();
    final i = _cache.indexWhere((e) => e.id == postId);
    if (i < 0) return;
    _cache[i] = _cache[i].copyWith(memberId: memberId);
    await _persist();
  }

  static Future<void> clearMember(String postId) async {
    await ensureLoaded();
    final i = _cache.indexWhere((e) => e.id == postId);
    if (i < 0) return;
    _cache[i] = _cache[i].copyWith(clearMember: true);
    await _persist();
  }

  static Future<BoardPost> addPost(String title) async {
    await ensureLoaded();
    final t = title.trim();
    if (t.isEmpty) {
      throw ArgumentError('Post title empty');
    }
    final maxOrder = _cache.isEmpty
        ? 0
        : _cache.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b);
    final post = BoardPost(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      title: t,
      sortOrder: maxOrder + 1,
      isCustom: true,
    );
    _cache = [..._cache, post];
    await _persist();
    return post;
  }

  static Future<void> deletePost(String postId) async {
    await ensureLoaded();
    _cache = _cache.where((e) => e.id != postId).toList();
    await _persist();
  }

  static Future<void> renamePost(String postId, String title) async {
    await ensureLoaded();
    final t = title.trim();
    if (t.isEmpty) return;
    final i = _cache.indexWhere((e) => e.id == postId);
    if (i < 0) return;
    _cache[i] = _cache[i].copyWith(title: t);
    await _persist();
  }

  static BoardPost? byId(String id) {
    if (id.trim().isEmpty) return null;
    for (final p in _cache) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Posts assigned to this member (sorted).
  static List<BoardPost> postsForMember(String memberId) {
    final id = memberId.trim();
    if (id.isEmpty) return const [];
    return current.where((p) => p.memberId == id).toList();
  }

  /// Board pe assigned VP-1 / VP-2 / VP-3 member id (level = 1/2/3).
  static String memberIdForVpLevel(int level) {
    if (level < 1 || level > 3) return '';
    // 1) Title se seedha VP level (V.P.-1 / V.P. -1 / VP 1 …)
    for (final post in current) {
      if (BoardPostRoleMapper.vpLevelFromTitle(post.title) != level) continue;
      final id = post.memberId.trim();
      if (id.isNotEmpty) return id;
    }
    // 2) Role mapper fallback
    final ClubRole role = switch (level) {
      1 => ClubRole.vp1,
      2 => ClubRole.vp2,
      _ => ClubRole.vp3,
    };
    for (final post in current) {
      if (BoardPostRoleMapper.roleForPost(post) != role) continue;
      final id = post.memberId.trim();
      if (id.isNotEmpty) return id;
    }
    return '';
  }

  /// Display label for VP seat (board member name if assigned).
  static String vpSeatLabel(int level, {String Function(String id)? nameOf}) {
    final id = memberIdForVpLevel(level);
    if (id.isEmpty) return '$level';
    final name = (nameOf?.call(id) ?? '').trim();
    if (name.isEmpty) return '$level';
    return '$level — $name';
  }

  /// If a member is deleted from Members, clear their board seats.
  static Future<void> clearMemberEverywhere(String memberId) async {
    await ensureLoaded();
    var changed = false;
    _cache = _cache.map((e) {
      if (e.memberId == memberId) {
        changed = true;
        return e.copyWith(clearMember: true);
      }
      return e;
    }).toList();
    if (changed) await _persist();
  }
}
