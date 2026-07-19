import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/member.dart';
import '../models/planned_program.dart';
import 'board_store.dart';
import 'planner_store.dart';

class PlannerImportResult {
  const PlannerImportResult({
    required this.imported,
    required this.skipped,
    this.errors = const [],
  });

  final int imported;
  final int skipped;
  final List<String> errors;
}

class PlannerExcelImport {
  static const headers = [
    'MONTH',
    'PROGRAM',
    'DATE',
    'BUDGET',
    'PC',
    'PC2',
    'PC3',
    'PC4',
    'DIRECTOR_VP',
    'PLACE',
    'TIME',
    'NOTES',
    'YEAR',
  ];

  /// Excel + CSV/TSV (Mac Numbers → Export → CSV / Excel).
  static const allowedExtensions = [
    'xlsx',
    'xls',
    'csv',
    'tsv',
    'txt',
    'numbers',
  ];

  static Uint8List buildCsvTemplateBytes() {
    final y = DateTime.now().year;
    // PC 1–4 + DIRECTOR_VP = 1 / 2 / 3 (Board VP auto)
    final sample = [
      'July',
      'Eye Camp',
      '15/07/$y',
      '25000',
      '9876543210',
      'Lion PC Two',
      '',
      '',
      '1',
      'Club Hall',
      '10:00',
      'District program',
      '$y',
    ];
    final body = [
      headers.join(','),
      sample.map(_csvEscape).join(','),
    ].join('\n');
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(body)]);
  }

  static String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static Future<(PlannerImportResult, List<PlannedProgram>)> parseFile({
    required String fileName,
    required Uint8List bytes,
    required List<Member> members,
  }) async {
    await BoardStore.ensureLoaded();
    final lower = fileName.toLowerCase();
    try {
      if (lower.endsWith('.numbers')) {
        return (
          const PlannerImportResult(
            imported: 0,
            skipped: 0,
            errors: [
              'Mac Numbers (.numbers) seedha nahi khulta.\n'
                  'Numbers → File → Export To → CSV (ya Excel) → woh file load karein.',
            ],
          ),
          <PlannedProgram>[],
        );
      }
      if (lower.endsWith('.csv') ||
          lower.endsWith('.tsv') ||
          lower.endsWith('.txt')) {
        return _fromRows(
          _parseDelimited(bytes, lower.endsWith('.tsv') ? '\t' : ','),
          members,
        );
      }
      return _fromRows(_parseExcel(bytes), members);
    } catch (e) {
      return (
        PlannerImportResult(
          imported: 0,
          skipped: 0,
          errors: ['File error: $e'],
        ),
        <PlannedProgram>[],
      );
    }
  }

  static List<List<String>> _parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];
    final sheet = excel.tables.values.first;
    final maxCols = sheet.maxColumns < 1 ? 12 : sheet.maxColumns;
    final rows = <List<String>>[];
    for (var r = 0; r < sheet.maxRows; r++) {
      final row = <String>[];
      for (var c = 0; c < maxCols; c++) {
        try {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
          );
          row.add(_cellToString(cell.value).trim());
        } catch (_) {
          row.add('');
        }
      }
      rows.add(row);
    }
    return rows;
  }

  static List<List<String>> _parseDelimited(Uint8List bytes, String sep) {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    final rows = <List<String>>[];
    for (final line in text.split(RegExp(r'\r?\n'))) {
      if (line.trim().isEmpty) continue;
      rows.add(_splitCsv(line, sep));
    }
    return rows;
  }

  static List<String> _splitCsv(String line, String sep) {
    if (sep == '\t') return line.split('\t');
    final out = <String>[];
    final buf = StringBuffer();
    var inQ = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQ && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQ = !inQ;
        }
      } else if (ch == sep && !inQ) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    out.add(buf.toString());
    return out;
  }

  static (PlannerImportResult, List<PlannedProgram>) _fromRows(
    List<List<String>> rows,
    List<Member> members,
  ) {
    if (rows.isEmpty) {
      return (
        const PlannerImportResult(
          imported: 0,
          skipped: 0,
          errors: ['File empty'],
        ),
        <PlannedProgram>[],
      );
    }

    final headerIdx = _findHeader(rows);
    final col = headerIdx >= 0 ? _mapHeaders(rows[headerIdx]) : <String, int>{};
    final start = headerIdx >= 0 ? headerIdx + 1 : 0;

    String cell(List<String> row, String key, int fb) {
      final i = col[key] ?? fb;
      if (i < 0 || i >= row.length) return '';
      return row[i].trim();
    }

    final out = <PlannedProgram>[];
    var skipped = 0;
    final yearNow = DateTime.now().year;

    for (var r = start; r < rows.length; r++) {
      final row = rows[r];
      if (row.every((e) => e.trim().isEmpty)) {
        skipped++;
        continue;
      }
      final title = cell(row, 'program', 1);
      if (title.isEmpty || title.toLowerCase() == 'program') {
        skipped++;
        continue;
      }

      final monthRaw = cell(row, 'month', 0);
      final dateRaw = cell(row, 'date', 2);
      final budgetRaw = cell(row, 'budget', 3);
      final pc1 = cell(row, 'pc', 4);
      final pc2 = cell(row, 'pc2', 5);
      final pc3 = cell(row, 'pc3', 6);
      final pc4 = cell(row, 'pc4', 7);
      final directorVpRaw = cell(row, 'director_vp', 8);
      final place = cell(row, 'place', 9);
      final time = cell(row, 'time', 10);
      final notes = cell(row, 'notes', 11);
      final yearRaw = cell(row, 'year', 12);
      final directorRaw = cell(row, 'director', -1);

      // Legacy columns (VP1/VP2/VP3) agar naye columns na hon
      final legacyVp1 = cell(row, 'vp1', -1);
      final legacyVp2 = cell(row, 'vp2', -1);
      final legacyVp3 = cell(row, 'vp3', -1);

      var month = PlannedProgram.parseMonth(monthRaw) ?? 0;
      final date = _normalizeDate(dateRaw);
      final parsedDate = Member.parseFlexibleDate(date);
      if (month == 0 && parsedDate != null) month = parsedDate.month;

      var year = int.tryParse(yearRaw) ?? 0;
      if (year < 2000 && parsedDate != null) year = parsedDate.year;
      if (year < 2000) year = yearNow;

      final budget = double.tryParse(
            budgetRaw.replaceAll(RegExp(r'[^\d.]'), ''),
          ) ??
          0;

      final pcIds = <String>[];
      void addPcRaw(String raw) {
        for (final part in raw.split(RegExp(r'[;|/]'))) {
          final id = _matchMemberId(members, part.trim());
          if (id.isEmpty || pcIds.contains(id)) continue;
          pcIds.add(id);
          if (pcIds.length >= PlannedProgram.maxPcs) break;
        }
      }

      addPcRaw(pc1);
      if (pcIds.length < PlannedProgram.maxPcs) addPcRaw(pc2);
      if (pcIds.length < PlannedProgram.maxPcs) addPcRaw(pc3);
      if (pcIds.length < PlannedProgram.maxPcs) addPcRaw(pc4);

      var vpLevel = _parseVpLevel(directorVpRaw);
      if (vpLevel < 1) {
        if (legacyVp1.isNotEmpty) {
          vpLevel = 1;
        } else if (legacyVp2.isNotEmpty) {
          vpLevel = 2;
        } else if (legacyVp3.isNotEmpty) {
          vpLevel = 3;
        }
      }
      // Board pe VP decided — DIRECTOR_VP = 1/2/3 se auto member
      var directorId =
          vpLevel >= 1 ? BoardStore.memberIdForVpLevel(vpLevel) : '';
      if (directorId.isEmpty && directorRaw.isNotEmpty) {
        directorId = _matchMemberId(members, directorRaw);
      }
      if (directorId.isEmpty) {
        if (legacyVp1.isNotEmpty) {
          directorId = _matchMemberId(members, legacyVp1);
        } else if (legacyVp2.isNotEmpty) {
          directorId = _matchMemberId(members, legacyVp2);
        } else if (legacyVp3.isNotEmpty) {
          directorId = _matchMemberId(members, legacyVp3);
        }
      }
      if (directorId.isNotEmpty && vpLevel < 1) vpLevel = 1;

      out.add(
        PlannedProgram(
          id: PlannerStore.newId(),
          title: title,
          expectedDate: date,
          expectedTime: time,
          place: place,
          notes: notes,
          pcMemberIds: pcIds,
          directorMemberId: directorId,
          directorVpLevel: vpLevel,
          planMonth: month,
          planYear: year,
          estimatedBudget: budget,
          checklist: PlannedProgram.defaultChecklist(),
        ),
      );
    }

    if (out.isEmpty) {
      return (
        PlannerImportResult(
          imported: 0,
          skipped: skipped,
          errors: const [
            'Programs nahi mile.\n'
                'Columns: MONTH, PROGRAM, DATE, BUDGET, PC..PC4, '
                'DIRECTOR_VP (1/2/3)',
          ],
        ),
        <PlannedProgram>[],
      );
    }

    return (
      PlannerImportResult(imported: out.length, skipped: skipped),
      out,
    );
  }

  static int _parseVpLevel(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return 0;
    final n = int.tryParse(t.replaceAll(RegExp(r'[^\d]'), ''));
    if (n != null && (n == 1 || n == 2 || n == 3)) return n;
    if (t.contains('vp-1') || t.contains('vp1') || t.contains('v.p.-1')) {
      return 1;
    }
    if (t.contains('vp-2') || t.contains('vp2') || t.contains('v.p.-2')) {
      return 2;
    }
    if (t.contains('vp-3') || t.contains('vp3') || t.contains('v.p.-3')) {
      return 3;
    }
    return 0;
  }

  /// Name ya mobile number — Members list se match.
  static String _matchMemberId(List<Member> members, String raw) {
    final n = raw.trim().toLowerCase();
    if (n.isEmpty) return '';

    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 8) {
      final tail = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
      for (final m in members) {
        final p = m.phone.replaceAll(RegExp(r'\D'), '');
        if (p.isEmpty) continue;
        final pt = p.length > 10 ? p.substring(p.length - 10) : p;
        if (pt == tail || p == digits || p.endsWith(tail) || digits.endsWith(pt)) {
          return m.id;
        }
      }
    }

    for (final m in members) {
      if (m.displayName.trim().toLowerCase() == n) return m.id;
    }
    for (final m in members) {
      final d = m.displayName.trim().toLowerCase();
      if (d.contains(n) || n.contains(d)) return m.id;
    }
    return '';
  }

  static int _findHeader(List<List<String>> rows) {
    var best = -1;
    var score = 0;
    final lim = rows.length < 15 ? rows.length : 15;
    for (var i = 0; i < lim; i++) {
      final s = _headerScore(rows[i]);
      if (s > score) {
        score = s;
        best = i;
      }
    }
    return score >= 2 ? best : -1;
  }

  static int _headerScore(List<String> row) {
    var s = 0;
    for (final raw in row) {
      final h = raw.toLowerCase().trim();
      if (h.contains('program') || h.contains('title') || h.contains('कार्यक्रम')) {
        s += 3;
      }
      if (h.contains('month') || h.contains('माह')) s += 2;
      if (h.contains('date') || h.contains('तारीख')) s += 2;
      if (h.contains('budget') || h.contains('बजट')) s += 2;
      if (h == 'pc' || h.contains('chair')) s += 1;
      if (h.contains('vp')) s += 1;
    }
    return s;
  }

  static Map<String, int> _mapHeaders(List<String> header) {
    final map = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      final h = header[i].toLowerCase().trim();
      if (h.isEmpty) continue;
      if (h.contains('month') || h.contains('माह')) {
        map.putIfAbsent('month', () => i);
      } else if (h.contains('program') ||
          h.contains('title') ||
          h.contains('कार्यक्रम') ||
          h == 'name') {
        map.putIfAbsent('program', () => i);
      } else if (h.contains('date') || h.contains('तारीख')) {
        map.putIfAbsent('date', () => i);
      } else if (h.contains('budget') || h.contains('बजट') || h.contains('amount')) {
        map.putIfAbsent('budget', () => i);
      } else if (h == 'pc2' || h == 'pc 2' || h.contains('pc-2')) {
        map.putIfAbsent('pc2', () => i);
      } else if (h == 'pc3' || h == 'pc 3' || h.contains('pc-3')) {
        map.putIfAbsent('pc3', () => i);
      } else if (h == 'pc4' || h == 'pc 4' || h.contains('pc-4')) {
        map.putIfAbsent('pc4', () => i);
      } else if (h == 'pc' ||
          h.contains('program chair') ||
          h.contains('chairperson') ||
          (h.contains('pc') && h.length <= 6)) {
        map.putIfAbsent('pc', () => i);
      } else if (h.contains('director_vp') ||
          h.contains('director vp') ||
          h == 'vp level' ||
          h == 'vp_level' ||
          (h.contains('director') && h.contains('vp'))) {
        map.putIfAbsent('director_vp', () => i);
      } else if (h == 'director' ||
          h.contains('program director') ||
          (h.contains('director') && !h.contains('vp'))) {
        map.putIfAbsent('director', () => i);
      } else if (h.contains('vp1') ||
          h.contains('vp-1') ||
          h.contains('v.p.-1')) {
        map.putIfAbsent('vp1', () => i);
      } else if (h.contains('vp2') ||
          h.contains('vp-2') ||
          h.contains('v.p.-2')) {
        map.putIfAbsent('vp2', () => i);
      } else if (h.contains('vp3') ||
          h.contains('vp-3') ||
          h.contains('v.p.-3')) {
        map.putIfAbsent('vp3', () => i);
      } else if (h.contains('place') || h.contains('venue')) {
        map.putIfAbsent('place', () => i);
      } else if (h.contains('time') || h.contains('समय')) {
        map.putIfAbsent('time', () => i);
      } else if (h.contains('note') || h.contains('remark')) {
        map.putIfAbsent('notes', () => i);
      } else if (h.contains('year') || h.contains('वर्ष')) {
        map.putIfAbsent('year', () => i);
      }
    }
    return map;
  }

  static String _normalizeDate(String raw) {
    final d = Member.parseFlexibleDate(raw);
    if (d != null) return Member.formatDate(d);
    return raw.trim();
  }

  static String _cellToString(CellValue? value) {
    if (value == null) return '';
    if (value is TextCellValue) return value.value.toString();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) {
      final d = value.value;
      if (d == d.roundToDouble()) return d.round().toString();
      return d.toString();
    }
    if (value is DateCellValue) {
      return Member.formatDate(DateTime(value.year, value.month, value.day));
    }
    if (value is BoolCellValue) return value.value ? 'true' : 'false';
    return value.toString();
  }
}
