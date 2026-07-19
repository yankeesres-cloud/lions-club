import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/post_desk.dart';

class DeskDraft {
  const DeskDraft({
    required this.desk,
    this.programName = '',
    this.date = '',
    this.place = '',
    this.guestOrNote = '',
    this.draftText = '',
    this.updatedAt,
  });

  final DeskType desk;
  final String programName;
  final String date;
  final String place;
  final String guestOrNote;
  final String draftText;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'desk': desk.name,
        'programName': programName,
        'date': date,
        'place': place,
        'guestOrNote': guestOrNote,
        'draftText': draftText,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory DeskDraft.fromJson(Map<String, dynamic> j) {
    final deskName = (j['desk'] ?? DeskType.agenda.name).toString();
    final desk = DeskType.values.firstWhere(
      (d) => d.name == deskName,
      orElse: () => DeskType.agenda,
    );
    return DeskDraft(
      desk: desk,
      programName: (j['programName'] ?? '').toString(),
      date: (j['date'] ?? '').toString(),
      place: (j['place'] ?? '').toString(),
      guestOrNote: (j['guestOrNote'] ?? '').toString(),
      draftText: (j['draftText'] ?? '').toString(),
      updatedAt: DateTime.tryParse((j['updatedAt'] ?? '').toString()),
    );
  }
}

class DeskDraftStore {
  static const _kPrefix = 'lions_desk_draft_';

  static Future<DeskDraft?> load(DeskType desk) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('$_kPrefix${desk.name}');
    if (raw == null || raw.isEmpty) return null;
    try {
      return DeskDraft.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(DeskDraft draft) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      '$_kPrefix${draft.desk.name}',
      jsonEncode(draft.copyWithNow().toJson()),
    );
  }

  /// Recent desk activity across all tools (anya members / posts ka kaam).
  static Future<List<DeskDraft>> loadRecent({int limit = 12}) async {
    final out = <DeskDraft>[];
    for (final desk in DeskType.values) {
      final d = await load(desk);
      if (d != null && d.draftText.trim().isNotEmpty) {
        out.add(d);
      }
    }
    out.sort((a, b) {
      final da = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    if (out.length <= limit) return out;
    return out.sublist(0, limit);
  }
}

extension on DeskDraft {
  DeskDraft copyWithNow() => DeskDraft(
        desk: desk,
        programName: programName,
        date: date,
        place: place,
        guestOrNote: guestOrNote,
        draftText: draftText,
        updatedAt: DateTime.now(),
      );
}
