import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ClubChatMessage {
  const ClubChatMessage({
    required this.id,
    required this.senderName,
    this.senderMemberId = '',
    this.text = '',
    this.photoPath = '',
    this.filePath = '',
    this.fileName = '',
    this.phoneNumber = '',
    required this.createdAtMs,
  });

  final String id;
  final String senderName;
  final String senderMemberId;
  final String text;
  final String photoPath;
  final String filePath;
  final String fileName;
  final String phoneNumber;
  final int createdAtMs;

  bool get hasPhoto => photoPath.trim().isNotEmpty;
  bool get hasFile => filePath.trim().isNotEmpty || fileName.trim().isNotEmpty;
  bool get hasPhone => phoneNumber.trim().isNotEmpty;
  bool get hasText => text.trim().isNotEmpty;
  bool get hasContent => hasText || hasPhoto || hasFile || hasPhone;

  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderName': senderName,
        'senderMemberId': senderMemberId,
        'text': text,
        'photoPath': photoPath,
        'filePath': filePath,
        'fileName': fileName,
        'phoneNumber': phoneNumber,
        'createdAtMs': createdAtMs,
      };

  factory ClubChatMessage.fromJson(Map<String, dynamic> j) {
    return ClubChatMessage(
      id: (j['id'] ?? '').toString(),
      senderName: (j['senderName'] ?? 'Member').toString(),
      senderMemberId: (j['senderMemberId'] ?? '').toString(),
      text: (j['text'] ?? '').toString(),
      photoPath: (j['photoPath'] ?? '').toString(),
      filePath: (j['filePath'] ?? '').toString(),
      fileName: (j['fileName'] ?? '').toString(),
      phoneNumber: (j['phoneNumber'] ?? '').toString(),
      createdAtMs: (j['createdAtMs'] is num)
          ? (j['createdAtMs'] as num).toInt()
          : int.tryParse('${j['createdAtMs']}') ?? 0,
    );
  }
}

/// Club-wide wall — sab members padh / likh sakte hain (local V1).
class ClubChatStore {
  static const _k = 'lions_club_chat_v1';
  static List<ClubChatMessage> _cache = [];
  static bool _loaded = false;

  static List<ClubChatMessage> get messages => List.unmodifiable(_cache);

  static Future<List<ClubChatMessage>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null || raw.isEmpty) {
      _cache = [];
      _loaded = true;
      return messages;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _cache = list
          .whereType<Map>()
          .map((e) => ClubChatMessage.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList()
        ..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    } catch (_) {
      _cache = [];
    }
    _loaded = true;
    return messages;
  }

  static Future<List<ClubChatMessage>> ensureLoaded() async {
    if (_loaded) return messages;
    return load();
  }

  static Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _k,
      jsonEncode(_cache.map((e) => e.toJson()).toList()),
    );
  }

  static Future<ClubChatMessage> send({
    required String senderName,
    String senderMemberId = '',
    String text = '',
    String photoPath = '',
    String filePath = '',
    String fileName = '',
    String phoneNumber = '',
  }) async {
    await ensureLoaded();
    final msg = ClubChatMessage(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}',
      senderName: senderName.trim().isEmpty ? 'Member' : senderName.trim(),
      senderMemberId: senderMemberId.trim(),
      text: text.trim(),
      photoPath: photoPath.trim(),
      filePath: filePath.trim(),
      fileName: fileName.trim(),
      phoneNumber: phoneNumber.trim(),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (!msg.hasContent) return msg;
    _cache = [..._cache, msg];
    await _persist();
    return msg;
  }

  static Future<void> delete(String id) async {
    await ensureLoaded();
    _cache = _cache.where((e) => e.id != id).toList();
    await _persist();
  }
}
