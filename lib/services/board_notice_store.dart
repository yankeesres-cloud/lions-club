import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BoardNotice {
  const BoardNotice({
    required this.id,
    required this.senderName,
    this.senderMemberId = '',
    this.boardPost = '',
    required this.text,
    required this.createdAtMs,
    required this.expiresAtMs,
  });

  final String id;
  final String senderName;
  final String senderMemberId;
  final String boardPost;
  final String text;
  final int createdAtMs;
  final int expiresAtMs;

  static const defaultTtlDays = 5;

  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  DateTime get expiresAt =>
      DateTime.fromMillisecondsSinceEpoch(expiresAtMs);

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get daysLeft {
    final d = expiresAt.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderName': senderName,
        'senderMemberId': senderMemberId,
        'boardPost': boardPost,
        'text': text,
        'createdAtMs': createdAtMs,
        'expiresAtMs': expiresAtMs,
      };

  factory BoardNotice.fromJson(Map<String, dynamic> j) {
    final created = (j['createdAtMs'] is num)
        ? (j['createdAtMs'] as num).toInt()
        : int.tryParse('${j['createdAtMs']}') ?? 0;
    var expires = (j['expiresAtMs'] is num)
        ? (j['expiresAtMs'] as num).toInt()
        : int.tryParse('${j['expiresAtMs']}') ?? 0;
    // Purane records: default 5 din.
    if (expires <= 0 && created > 0) {
      expires = DateTime.fromMillisecondsSinceEpoch(created)
          .add(const Duration(days: defaultTtlDays))
          .millisecondsSinceEpoch;
    }
    return BoardNotice(
      id: (j['id'] ?? '').toString(),
      senderName: (j['senderName'] ?? 'Board').toString(),
      senderMemberId: (j['senderMemberId'] ?? '').toString(),
      boardPost: (j['boardPost'] ?? '').toString(),
      text: (j['text'] ?? '').toString(),
      createdAtMs: created,
      expiresAtMs: expires,
    );
  }
}

/// Sirf Board members post — har message ka apna date/time + din.
class BoardNoticeStore {
  static const _k = 'lions_board_notices_v1';
  static List<BoardNotice> _cache = [];
  static bool _loaded = false;

  static List<BoardNotice> get active =>
      List.unmodifiable(_cache.where((e) => !e.isExpired));

  static Future<List<BoardNotice>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null || raw.isEmpty) {
      _cache = [];
      _loaded = true;
      return active;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _cache = list
          .whereType<Map>()
          .map((e) => BoardNotice.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty && e.text.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    } catch (_) {
      _cache = [];
    }
    await _pruneExpired();
    _loaded = true;
    return active;
  }

  static Future<List<BoardNotice>> ensureLoaded() async {
    if (_loaded) {
      await _pruneExpired();
      return active;
    }
    return load();
  }

  static Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _k,
      jsonEncode(_cache.map((e) => e.toJson()).toList()),
    );
    changes.ping();
  }

  static final changes = _BoardNoticeChanges();

  static Future<void> _pruneExpired() async {
    final before = _cache.length;
    _cache = _cache.where((e) => !e.isExpired).toList();
    if (_cache.length != before) await _persist();
  }

  static Future<BoardNotice?> post({
    required String senderName,
    String senderMemberId = '',
    String boardPost = '',
    required String text,
    DateTime? createdAt,
    int showDays = BoardNotice.defaultTtlDays,
  }) async {
    await ensureLoaded();
    final t = text.trim();
    if (t.isEmpty) return null;
    final days = showDays < 1 ? 1 : (showDays > 365 ? 365 : showDays);
    final created = createdAt ?? DateTime.now();
    final expires = created.add(Duration(days: days));
    final n = BoardNotice(
      id: 'bn_${DateTime.now().microsecondsSinceEpoch}',
      senderName: senderName.trim().isEmpty ? 'Board' : senderName.trim(),
      senderMemberId: senderMemberId.trim(),
      boardPost: boardPost.trim(),
      text: t,
      createdAtMs: created.millisecondsSinceEpoch,
      expiresAtMs: expires.millisecondsSinceEpoch,
    );
    _cache = [n, ..._cache];
    await _persist();
    return n;
  }

  static Future<void> delete(String id) async {
    await ensureLoaded();
    _cache = _cache.where((e) => e.id != id).toList();
    await _persist();
  }
}

class _BoardNoticeChanges extends ChangeNotifier {
  void ping() => notifyListeners();
}
