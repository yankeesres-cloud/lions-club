import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class GalleryPhoto {
  const GalleryPhoto({
    required this.id,
    required this.path,
    this.caption = '',
    this.programName = '',
    this.date = '',
  });

  final String id;
  final String path;
  final String caption;
  final String programName;
  final String date;

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'caption': caption,
        'programName': programName,
        'date': date,
      };

  factory GalleryPhoto.fromJson(Map<String, dynamic> j) {
    return GalleryPhoto(
      id: (j['id'] ?? '').toString(),
      path: (j['path'] ?? '').toString(),
      caption: (j['caption'] ?? '').toString(),
      programName: (j['programName'] ?? '').toString(),
      date: (j['date'] ?? '').toString(),
    );
  }
}

class GalleryStore {
  static const _k = 'lions_gallery_v1';
  static List<GalleryPhoto> _cache = [];
  static bool _loaded = false;

  static List<GalleryPhoto> get current => List.unmodifiable(_cache);

  static Future<List<GalleryPhoto>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null || raw.isEmpty) {
      _cache = [];
      _loaded = true;
      return current;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _cache = list
          .whereType<Map>()
          .map((e) => GalleryPhoto.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty && e.path.isNotEmpty)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (_) {
      _cache = [];
    }
    _loaded = true;
    return current;
  }

  static Future<List<GalleryPhoto>> ensureLoaded() async {
    if (_loaded) return current;
    return load();
  }

  static Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(_cache.map((e) => e.toJson()).toList()));
  }

  static Future<void> add(GalleryPhoto photo) async {
    await ensureLoaded();
    _cache = [photo, ..._cache];
    await _persist();
  }

  static Future<void> delete(String id) async {
    await ensureLoaded();
    _cache = _cache.where((e) => e.id != id).toList();
    await _persist();
  }

  static String newId() => 'g_${DateTime.now().microsecondsSinceEpoch}';
}
