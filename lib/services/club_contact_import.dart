import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/club_contact.dart';
import 'club_contact_store.dart';

class ContactImportResult {
  const ContactImportResult({
    required this.imported,
    required this.skipped,
    this.errors = const [],
  });

  final int imported;
  final int skipped;
  final List<String> errors;
}

/// Anya club / Lions guest directory — Excel/CSV (flexible columns).
class ClubContactImport {
  /// Preferred Excel order (club pehle).
  static const headers = [
    'CLUB',
    'NAME',
    'DESIGNATION',
    'PHONE',
    'DISTRICT',
    'CITY',
    'NOTES',
  ];

  static const allowedExtensions = [
    'xlsx',
    'xls',
    'csv',
    'tsv',
    'txt',
  ];

  static Uint8List buildCsvTemplateBytes() {
    final sample = [
      'Lions Club Sample',
      'Lion Sample Guest',
      'Past President',
      '9876543210',
      '322-B1',
      'Gwalior',
      'Visit note',
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

  static Future<(ContactImportResult, List<ClubContact>)> parseFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final lower = fileName.toLowerCase();
    try {
      if (lower.endsWith('.pdf')) {
        return (
          const ContactImportResult(
            imported: 0,
            skipped: 0,
            errors: [
              'PDF import band — guest list ke liye Excel (.xlsx) ya CSV use karein.\n'
                  'CSV template download karke columns bhar sakte ho.',
            ],
          ),
          <ClubContact>[],
        );
      }
      if (lower.endsWith('.csv') ||
          lower.endsWith('.tsv') ||
          lower.endsWith('.txt')) {
        return _parseDelimited(bytes, lower.endsWith('.tsv') ? '\t' : ',');
      }
      return _parseExcel(bytes);
    } catch (e) {
      return (
        ContactImportResult(
          imported: 0,
          skipped: 0,
          errors: ['File padhne mein error: $e'],
        ),
        <ClubContact>[],
      );
    }
  }

  static (ContactImportResult, List<ClubContact>) _parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return (
        const ContactImportResult(
          imported: 0,
          skipped: 0,
          errors: ['Excel sheet khali hai'],
        ),
        <ClubContact>[],
      );
    }

    // Prefer the sheet with the most non-empty rows.
    Sheet? best;
    var bestScore = -1;
    for (final sheet in excel.tables.values) {
      var score = 0;
      for (var r = 0; r < sheet.maxRows; r++) {
        final row = sheet.rows.length > r ? sheet.rows[r] : const <Data?>[];
        if (row.any((c) => _cellToString(c?.value).trim().isNotEmpty)) {
          score++;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = sheet;
      }
    }
    final sheet = best ?? excel.tables.values.first;

    final maxCols = sheet.maxColumns < 1 ? 12 : sheet.maxColumns;
    final rows = <List<String>>[];
    for (var r = 0; r < sheet.maxRows; r++) {
      final row = <String>[];
      for (var c = 0; c < maxCols; c++) {
        String v = '';
        try {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
          );
          v = _cellToString(cell.value);
        } catch (_) {
          if (r < sheet.rows.length && c < sheet.rows[r].length) {
            v = _cellToString(sheet.rows[r][c]?.value);
          }
        }
        row.add(v.trim());
      }
      rows.add(row);
    }
    return _rowsToContacts(rows);
  }

  static (ContactImportResult, List<ClubContact>) _parseDelimited(
    Uint8List bytes,
    String sep,
  ) {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    final lines =
        text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty);
    final rows = <List<String>>[];
    for (final line in lines) {
      rows.add(_splitCsvLine(line, sep));
    }
    return _rowsToContacts(rows);
  }

  static List<String> _splitCsvLine(String line, String sep) {
    if (sep == '\t') return line.split('\t');
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == sep && !inQuotes) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    out.add(buf.toString());
    return out;
  }

  static (ContactImportResult, List<ClubContact>) _rowsToContacts(
    List<List<String>> rows,
  ) {
    if (rows.isEmpty) {
      return (
        const ContactImportResult(
          imported: 0,
          skipped: 0,
          errors: ['File empty'],
        ),
        <ClubContact>[],
      );
    }

    final headerIdx = _findHeaderRow(rows);
    var col = headerIdx >= 0
        ? _mapHeaders(rows[headerIdx])
        : <String, int>{};
    final start = headerIdx >= 0 ? headerIdx + 1 : 0;

    if (col.isEmpty || !col.containsKey('name')) {
      col = {
        ...col,
        ..._inferColumns(rows, start),
      };
    }

    final contacts = <ClubContact>[];
    var skipped = 0;
    // Excel mein kabhi club sirf pehli row pe hota hai — aage blank = same club.
    var lastClub = '';

    // Default column order if headers weak: CLUB | NAME | POST | PHONE
    final fallbackClub = col['club'] ?? 0;
    final fallbackName = col['name'] ?? 1;
    final fallbackPost = col['designation'] ?? 2;
    final fallbackPhone = col['phone'] ?? 3;

    String cell(List<String> row, String key, [int fallback = -1]) {
      final idx = col[key] ?? fallback;
      if (idx < 0 || idx >= row.length) return '';
      return row[idx].trim();
    }

    for (var r = start; r < rows.length; r++) {
      final row = rows[r];
      if (row.every((e) => e.trim().isEmpty)) {
        skipped++;
        continue;
      }

      // Skip banner / title rows
      final joined = row.where((e) => e.trim().isNotEmpty).join(' ').toLowerCase();
      if (joined.contains('guest list') && !joined.contains('mobile')) {
        skipped++;
        continue;
      }
      if (_looksLikeHeaderRow(row)) {
        skipped++;
        continue;
      }

      var name = cell(row, 'name', fallbackName);
      var phone = _normalizePhone(cell(row, 'phone', fallbackPhone));
      var club = cell(row, 'club', fallbackClub);
      var post = cell(row, 'designation', fallbackPost);
      var district = cell(row, 'district');
      var city = cell(row, 'city');
      var notes = cell(row, 'notes');

      // Phone: scan whole row
      if (phone.isEmpty) {
        for (final v in row) {
          final p = _normalizePhone(v);
          if (p.length >= 10) {
            phone = p;
            break;
          }
        }
      }

      // If mapped "name" is actually a club, move it.
      if (ClubContact.looksLikeClubOnly(name)) {
        if (club.isEmpty) club = name;
        name = '';
      }

      // Club cells
      if (club.isEmpty) {
        for (final v in row) {
          if (ClubContact.looksLikeClubOnly(v) ||
              (v.toLowerCase().contains('lions club'))) {
            club = v.trim();
            break;
          }
        }
      }

      // Carry-forward club name from previous row
      if (club.trim().isNotEmpty) {
        lastClub = club.trim();
      } else if (lastClub.isNotEmpty) {
        club = lastClub;
      }

      // Person name: first readable cell that is NOT club / phone / sno
      if (!_looksLikePersonName(name)) {
        for (final v in row) {
          final t = v.trim();
          if (t.isEmpty) continue;
          if (_normalizePhone(t).length >= 10) continue;
          if (ClubContact.looksLikeClubOnly(t)) continue;
          if (t.toLowerCase() == club.toLowerCase()) continue;
          if (RegExp(r'^\d{1,4}$').hasMatch(t)) continue; // S.No
          if (_looksLikePersonName(t)) {
            name = t;
            break;
          }
        }
      }

      // Post: leftover text cell (not name/club/phone)
      if (post.isEmpty) {
        for (final v in row) {
          final t = v.trim();
          if (t.isEmpty) continue;
          if (t.toLowerCase() == name.toLowerCase()) continue;
          if (t.toLowerCase() == club.toLowerCase()) continue;
          if (_normalizePhone(t).length >= 10) continue;
          if (ClubContact.looksLikeClubOnly(t)) continue;
          if (RegExp(r'^\d{1,4}$').hasMatch(t)) continue;
          if (_looksLikePersonName(t) || t.length >= 3) {
            post = t;
            break;
          }
        }
      }

      // Guest row must have person name + mobile (club-only rows skip)
      if (!_looksLikePersonName(name) || phone.length < 10) {
        skipped++;
        continue;
      }

      final c = ClubContact(
        id: ClubContactStore.newId(),
        name: name.trim(),
        phone: phone,
        clubName: _cleanField(club),
        district: _cleanField(district),
        designation: _cleanField(post),
        city: _cleanField(city),
        notes: _cleanField(notes),
      );

      if (c.isSane) {
        contacts.add(c);
      } else {
        final forced = ClubContact(
          id: c.id,
          name: c.name,
          phone: c.phone,
          clubName: ClubContact.fieldOk(c.clubName) ? c.clubName : '',
          designation: ClubContact.fieldOk(c.designation) ? c.designation : '',
          district: ClubContact.fieldOk(c.district) ? c.district : '',
          city: ClubContact.fieldOk(c.city) ? c.city : '',
          notes: ClubContact.fieldOk(c.notes) ? c.notes : '',
        );
        if (forced.isSane) {
          contacts.add(forced);
        } else {
          skipped++;
        }
      }
    }

    if (contacts.isEmpty) {
      return (
        ContactImportResult(
          imported: 0,
          skipped: skipped,
          errors: [
            'Excel se contacts nahi mile.\n'
                'Columns hona chahiye: Name, Phone/Mobile, Club, Designation/Post.\n'
                'Pehli rows title ho to theek — header auto-detect hota hai.\n'
                '(Skipped rows: $skipped)',
          ],
        ),
        <ClubContact>[],
      );
    }

    return (
      ContactImportResult(imported: contacts.length, skipped: skipped),
      contacts,
    );
  }

  /// Avoid private API — duplicate field clean check.
  static String _cleanField(String s) {
    final t = s.trim();
    if (t.isEmpty) return '';
    final letters = RegExp(r'[A-Za-z\u0900-\u097F]').allMatches(t).length;
    final weird = RegExp(
      r"[^A-Za-z\u0900-\u097F0-9\s\-&./,()'+]",
    ).allMatches(t).length;
    if (letters >= 1 && weird <= letters) return t;
    return '';
  }

  static int _findHeaderRow(List<List<String>> rows) {
    var best = -1;
    var bestScore = 0;
    final limit = rows.length < 25 ? rows.length : 25;
    for (var i = 0; i < limit; i++) {
      final score = _headerScore(rows[i]);
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    return bestScore >= 2 ? best : -1;
  }

  static int _headerScore(List<String> row) {
    var score = 0;
    for (final raw in row) {
      final h = raw.toLowerCase().trim();
      if (h.isEmpty) continue;
      if (_isNameHeader(h)) score += 3;
      if (_isPhoneHeader(h)) score += 3;
      if (_isClubHeader(h)) score += 2;
      if (_isPostHeader(h)) score += 2;
      if (h.contains('district') || h.contains('city')) score += 1;
      if (h.contains('s.no') || h == 'sno' || h == 'sr' || h == '#') score += 1;
    }
    return score;
  }

  static bool _looksLikeHeaderRow(List<String> row) {
    return _headerScore(row) >= 4;
  }

  static Map<String, int> _mapHeaders(List<String> header) {
    final map = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      final h = header[i].toLowerCase().trim();
      if (h.isEmpty) continue;
      if (_isNameHeader(h)) {
        map.putIfAbsent('name', () => i);
      } else if (_isPhoneHeader(h)) {
        map.putIfAbsent('phone', () => i);
      } else if (_isClubHeader(h)) {
        map.putIfAbsent('club', () => i);
      } else if (h.contains('district') || h.contains('जिला')) {
        map.putIfAbsent('district', () => i);
      } else if (_isPostHeader(h)) {
        map.putIfAbsent('designation', () => i);
      } else if (h.contains('city') || h.contains('शहर') || h.contains('place')) {
        map.putIfAbsent('city', () => i);
      } else if (h.contains('note') || h.contains('remark')) {
        map.putIfAbsent('notes', () => i);
      }
    }
    return map;
  }

  static bool _isNameHeader(String h) {
    if (h.contains('club') && h.contains('name')) return false;
    return h == 'name' ||
        h.contains('lion name') ||
        h.contains('guest name') ||
        h.contains('member name') ||
        h == 'naam' ||
        h.contains('naam') ||
        (h.contains('name') && !h.contains('club') && !h.contains('file'));
  }

  static bool _isPhoneHeader(String h) {
    return h.contains('phone') ||
        h.contains('mobile') ||
        h.contains('contact no') ||
        h.contains('cell') ||
        h.contains('whatsapp') ||
        h.contains('मोबाइल') ||
        h == 'mob' ||
        h.contains('mob.');
  }

  static bool _isClubHeader(String h) {
    return h == 'club' ||
        h.contains('club name') ||
        h.contains('club\'s name') ||
        h.contains('lions club') ||
        (h.contains('club') && !h.contains('clubbers'));
  }

  static bool _isPostHeader(String h) {
    return h.contains('design') ||
        h.contains('post') ||
        h.contains('position') ||
        h.contains('office') ||
        h.contains('पद') ||
        h.contains('title') ||
        h.contains('portfolio');
  }

  /// Infer name/phone/club columns from data when headers missing/weak.
  static Map<String, int> _inferColumns(List<List<String>> rows, int start) {
    if (rows.isEmpty) return {};
    final width = rows.map((r) => r.length).fold<int>(0, (a, b) => a > b ? a : b);
    if (width == 0) return {};

    final phoneHits = List<int>.filled(width, 0);
    final nameHits = List<int>.filled(width, 0);
    final clubHits = List<int>.filled(width, 0);
    final end = rows.length < start + 40 ? rows.length : start + 40;

    for (var r = start; r < end; r++) {
      final row = rows[r];
      for (var c = 0; c < width; c++) {
        final v = c < row.length ? row[c].trim() : '';
        if (v.isEmpty) continue;
        if (_normalizePhone(v).length >= 10) phoneHits[c]++;
        if (ClubContact.looksLikeClubOnly(v) ||
            v.toLowerCase().contains('lions club')) {
          clubHits[c]++;
        } else if (_looksLikePersonName(v)) {
          nameHits[c]++;
        }
      }
    }

    int best(List<int> scores, {Set<int> exclude = const {}}) {
      var bi = -1;
      var bs = 0;
      for (var i = 0; i < scores.length; i++) {
        if (exclude.contains(i)) continue;
        if (scores[i] > bs) {
          bs = scores[i];
          bi = i;
        }
      }
      return bs > 0 ? bi : -1;
    }

    final phoneCol = best(phoneHits);
    final nameCol = best(nameHits, exclude: {if (phoneCol >= 0) phoneCol});
    final clubCol = best(
      clubHits,
      exclude: {
        if (phoneCol >= 0) phoneCol,
        if (nameCol >= 0) nameCol,
      },
    );

    final map = <String, int>{};
    if (nameCol >= 0) map['name'] = nameCol;
    if (phoneCol >= 0) map['phone'] = phoneCol;
    if (clubCol >= 0 && clubCol != nameCol) map['club'] = clubCol;

    // Designation = remaining text-heavy column
    for (var c = 0; c < width; c++) {
      if (c == nameCol || c == phoneCol || c == clubCol) continue;
      if (nameHits[c] > 0 && !map.containsKey('designation')) {
        map['designation'] = c;
      }
    }
    return map;
  }

  static bool _looksLikePersonName(String raw) {
    final n = raw.trim();
    if (n.length < 2 || n.length > 90) return false;
    if (RegExp(r'^\d+$').hasMatch(n)) return false;
    if (ClubContact.looksLikeClubOnly(n)) return false;
    if (_normalizePhone(n).length >= 10 &&
        !RegExp(r'[A-Za-z\u0900-\u097F]').hasMatch(n)) {
      return false;
    }
    final letters = RegExp(r'[A-Za-z\u0900-\u097F]').allMatches(n).length;
    return letters >= 2;
  }

  static String _normalizePhone(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length >= 12 && d.startsWith('91')) d = d.substring(d.length - 10);
    if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
    // Excel float residue
    if (d.length > 10 && d.endsWith('0') && d.length <= 12) {
      // keep as is; substring later if needed
    }
    if (d.length > 10) d = d.substring(d.length - 10);
    return d;
  }

  static String _cellToString(CellValue? value) {
    if (value == null) return '';
    if (value is TextCellValue) return value.value.toString();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) {
      final d = value.value;
      // Phone numbers stored as Excel numbers
      if (d >= 1e9 && d < 1e13 && d == d.roundToDouble()) {
        return d.round().toString();
      }
      if (d == d.roundToDouble()) return d.round().toString();
      return d.toString();
    }
    if (value is BoolCellValue) return value.value ? 'true' : 'false';
    return value.toString();
  }
}
