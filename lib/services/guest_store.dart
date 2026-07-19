import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/guest_post.dart';

class GuestStore {
  static const _kPosts = 'lions_guest_posts_v1';

  static List<GuestPost> _cache = [];
  static bool _loaded = false;

  static List<GuestPost> get current {
    final list = List<GuestPost>.of(_cache)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return List.unmodifiable(list);
  }

  static Future<List<GuestPost>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPosts);
    if (raw == null || raw.trim().isEmpty) {
      _cache = GuestDefaults.posts();
      _loaded = true;
      await _persist();
      return current;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _cache = list
          .whereType<Map>()
          .map((e) => GuestPost.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty && e.title.trim().isNotEmpty)
          .toList();
      if (_cache.isEmpty) {
        _cache = GuestDefaults.posts();
        await _persist();
      }
    } catch (_) {
      _cache = GuestDefaults.posts();
      await _persist();
    }
    _loaded = true;
    return current;
  }

  static Future<List<GuestPost>> ensureLoaded() async {
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

  static Future<void> upsert(GuestPost post) async {
    await ensureLoaded();
    final i = _cache.indexWhere((e) => e.id == post.id);
    if (i >= 0) {
      _cache[i] = post;
    } else {
      _cache = [..._cache, post];
    }
    await _persist();
  }

  static Future<void> clearPerson(String postId) async {
    await ensureLoaded();
    final i = _cache.indexWhere((e) => e.id == postId);
    if (i < 0) return;
    _cache[i] = _cache[i].copyWith(clearPerson: true);
    await _persist();
  }

  static Future<GuestPost> addPost(String title) async {
    await ensureLoaded();
    final t = title.trim();
    if (t.isEmpty) throw ArgumentError('Post title empty');
    final maxOrder = _cache.isEmpty
        ? 0
        : _cache.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b);
    final post = GuestPost(
      id: 'guest_custom_${DateTime.now().microsecondsSinceEpoch}',
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
}
