import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/member.dart';
import 'member_store.dart';

class MemberImportResult {
  const MemberImportResult({
    required this.imported,
    required this.skipped,
    this.errors = const [],
  });

  final int imported;
  final int skipped;
  final List<String> errors;
}

/// Excel (.xlsx/.xls) + CSV/TSV (Numbers / Google Sheets export).
class MemberExcelService {
  static const headers = [
    'LION NAME (M)',
    'PHONE NO (M)',
    'DOB (M)',
    'PROFESSION (M)',
    'LION NAME (F)',
    'PHONE NO (F)',
    'DOB (F)',
    'PROFESSION (F)',
    'ANNIVERSARY',
    'ADDRESS',
    'PROPOSER',
    'COUPLE/SINGLE MEMBER',
  ];

  static const allowedExtensions = [
    'xlsx',
    'xls',
    'csv',
    'tsv',
    'txt',
  ];

  static Uint8List buildTemplateBytes() {
    final excel = Excel.createExcel();
    final sheet = excel['Members'];
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    for (var c = 0; c < headers.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value =
          TextCellValue(headers[c]);
    }
    _writeSampleExcelRow(sheet, 1);
    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? []);
  }

  /// CSV template — Numbers mein File → Open se khul jata hai.
  static Uint8List buildCsvTemplateBytes() {
    final sample = [
      'Lion Sample',
      '9876543210',
      '15/08/1980',
      'Business',
      'Lioness Sample',
      '9876543211',
      '20/03/1985',
      'Teacher',
      '10/12/2005',
      'Gwalior',
      'Lion Proposer',
      'Couple',
    ];
    final lines = [
      headers.map(_csvEscape).join(','),
      sample.map(_csvEscape).join(','),
    ];
    // UTF-8 BOM so Numbers/Excel Hindi headers sahi padhein
    final body = lines.join('\n');
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(body)]);
  }

  static void _writeSampleExcelRow(Sheet sheet, int row) {
    final values = [
      'Lion Sample',
      '9876543210',
      '15/08/1980',
      'Business',
      'Lioness Sample',
      '9876543211',
      '20/03/1985',
      'Teacher',
      '10/12/2005',
      'Gwalior',
      'Lion Proposer',
      'Couple',
    ];
    for (var c = 0; c < values.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row)).value =
          TextCellValue(values[c]);
    }
  }

  static String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// Route by file name / extension. Supports Excel + CSV/TSV (Numbers export).
  static (MemberImportResult, List<Member>) parseFile({
    required Uint8List bytes,
    required String fileName,
  }) {
    final lower = fileName.toLowerCase().trim();
    if (lower.endsWith('.numbers')) {
      return (
        const MemberImportResult(
          imported: 0,
          skipped: 0,
          errors: [
            'Numbers (.numbers) seedha nahi khulta.\n'
                'Numbers → File → Export To → CSV (ya Excel) save karke woh file load karein.',
          ],
        ),
        <Member>[],
      );
    }

    // Old binary .xls (OLE) — never decode as CSV (creates � garbage).
    final isOldXls = _isOleCompound(bytes) ||
        (lower.endsWith('.xls') && !lower.endsWith('.xlsx'));
    if (isOldXls) {
      return (
        const MemberImportResult(
          imported: 0,
          skipped: 0,
          errors: [
            'Purana Excel (.xls) format support nahi.\n'
                'Excel/Numbers se Export → .xlsx ya .csv karke load karein.',
          ],
        ),
        <Member>[],
      );
    }

    if (lower.endsWith('.csv') || lower.endsWith('.tsv') || lower.endsWith('.txt')) {
      if (_isBinaryBlob(bytes)) {
        return (
          const MemberImportResult(
            imported: 0,
            skipped: 0,
            errors: [
              'Ye text/CSV nahi dikhta (binary file).\n'
                  'Numbers/Excel se Export → CSV ya Excel (.xlsx) karke try karein.',
            ],
          ),
          <Member>[],
        );
      }
      return parseCsvBytes(bytes, isTsv: lower.endsWith('.tsv'));
    }

    if (lower.endsWith('.xlsx') || _isZipXlsx(bytes)) {
      return parseExcelBytes(bytes);
    }

    // Unknown extension: only CSV if clearly text spreadsheet
    if (_isClearlyCsvText(bytes)) {
      return parseCsvBytes(bytes);
    }

    return (
      const MemberImportResult(
        imported: 0,
        skipped: 0,
        errors: [
          'File format samajh nahi aaya.\n'
              'Sirf .xlsx, .csv ya .tsv use karein (Numbers → Export To → CSV/Excel).',
        ],
      ),
      <Member>[],
    );
  }

  static bool _isZipXlsx(Uint8List bytes) =>
      bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;

  static bool _isOleCompound(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0xD0 &&
      bytes[1] == 0xCF &&
      bytes[2] == 0x11 &&
      bytes[3] == 0xE0;

  static bool _isBinaryBlob(Uint8List bytes) {
    if (_isZipXlsx(bytes) || _isOleCompound(bytes)) return true;
    final n = bytes.length < 512 ? bytes.length : 512;
    if (n == 0) return true;
    var weird = 0;
    for (var i = 0; i < n; i++) {
      final b = bytes[i];
      final ok = b == 9 || b == 10 || b == 13 || (b >= 32 && b < 127) || b >= 0xC0;
      if (!ok) weird++;
    }
    return weird / n > 0.15;
  }

  static bool _isClearlyCsvText(Uint8List bytes) {
    if (_isBinaryBlob(bytes)) return false;
    final probe = utf8.decode(bytes.take(400).toList(), allowMalformed: true);
    final line = probe.split(RegExp(r'\r?\n')).first.toLowerCase();
    final looksHeader = line.contains('name') ||
        line.contains('lion') ||
        line.contains('phone') ||
        line.contains('dob') ||
        line.contains('profes') ||
        line.contains('address');
    final hasDelim = line.contains(',') || line.contains('\t') || line.contains(';');
    return looksHeader && hasDelim;
  }

  static (MemberImportResult, List<Member>) parseBytes(Uint8List bytes) =>
      parseExcelBytes(bytes);

  static (MemberImportResult, List<Member>) parseExcelBytes(Uint8List bytes) {
    if (_isOleCompound(bytes)) {
      return (
        const MemberImportResult(
          imported: 0,
          skipped: 0,
          errors: [
            'Purana Excel (.xls) format support nahi.\n'
                'Save As → Excel Workbook (.xlsx) ya CSV karke load karein.',
          ],
        ),
        <Member>[],
      );
    }
    try {
      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) {
        return (
          const MemberImportResult(
            imported: 0,
            skipped: 0,
            errors: ['Excel/Numbers file empty / invalid'],
          ),
          <Member>[],
        );
      }
      final sheet = excel.tables.values.first;
      if (sheet.maxRows < 2) {
        return (
          const MemberImportResult(
            imported: 0,
            skipped: 0,
            errors: ['No data rows found'],
          ),
          <Member>[],
        );
      }

      final rows = <List<String>>[];
      for (var r = 0; r < sheet.maxRows; r++) {
        final row = sheet.rows[r];
        rows.add([
          for (var c = 0; c < row.length; c++) _cellToString(row[c]?.value),
        ]);
      }
      return _fromStringRows(rows);
    } catch (e) {
      // Never parse binary Excel as CSV — that creates � garbage members.
      return (
        MemberImportResult(
          imported: 0,
          skipped: 0,
          errors: [
            'Excel file padh nahi paye.\n'
                'Numbers/Excel se Export → CSV ya .xlsx karke phir try karein.\n($e)',
          ],
        ),
        <Member>[],
      );
    }
  }

  static (MemberImportResult, List<Member>) parseCsvBytes(
    Uint8List bytes, {
    bool isTsv = false,
  }) {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (text.isEmpty) {
      return (
        const MemberImportResult(
          imported: 0,
          skipped: 0,
          errors: ['CSV file empty'],
        ),
        <Member>[],
      );
    }

    final firstLine = text.split('\n').first;
    final delimiter = isTsv
        ? '\t'
        : _detectDelimiter(firstLine);
    final rows = _parseDelimited(text, delimiter);
    return _fromStringRows(rows);
  }

  static String _detectDelimiter(String firstLine) {
    final comma = ','.allMatches(firstLine).length;
    final semi = ';'.allMatches(firstLine).length;
    final tab = '\t'.allMatches(firstLine).length;
    if (tab >= comma && tab >= semi && tab > 0) return '\t';
    if (semi > comma) return ';';
    return ',';
  }

  /// RFC-ish CSV parser with quotes.
  static List<List<String>> _parseDelimited(String text, String delimiter) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          cell.write(ch);
        }
        continue;
      }
      if (ch == '"') {
        inQuotes = true;
        continue;
      }
      if (ch == delimiter) {
        row.add(cell.toString());
        cell.clear();
        continue;
      }
      if (ch == '\n') {
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = [];
        continue;
      }
      cell.write(ch);
    }
    row.add(cell.toString());
    if (row.any((e) => e.trim().isNotEmpty)) rows.add(row);
    return rows;
  }

  static (MemberImportResult, List<Member>) _fromStringRows(List<List<String>> rows) {
    if (rows.length < 2) {
      return (
        const MemberImportResult(
          imported: 0,
          skipped: 0,
          errors: ['No data rows found'],
        ),
        <Member>[],
      );
    }

    final col = _mapHeaderStrings(rows.first);
    final members = <Member>[];
    var skipped = 0;

    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      String cell(String key, [int? fallbackIndex]) {
        final idx = col[key] ?? fallbackIndex;
        if (idx == null || idx < 0 || idx >= row.length) return '';
        return row[idx].trim();
      }

      final nameM = cell('nameM', 0);
      final phoneM = cell('phoneM', 1);
      final dobM = cell('dobM', 2);
      final professionM = cell('professionM', 3);
      final nameF = cell('nameF', 4);
      final phoneF = cell('phoneF', 5);
      final dobF = cell('dobF', 6);
      final professionF = cell('professionF', 7);
      final anniversary = cell('anniversary', 8);
      final address = cell('address', 9);
      // Proposer: mapped header, else template col 10; skip Couple/Single values.
      var proposer = cell('proposer', 10);
      final typeRaw = cell('type', 11);
      if (_looksLikeMembershipType(proposer) && !_looksLikeMembershipType(typeRaw)) {
        // Columns shifted — proposer cell actually held type.
        proposer = '';
      }
      if (proposer.isEmpty) {
        // Last-resort: any unmapped-looking cell with a person-like name near end.
        for (var i = row.length - 1; i >= 0; i--) {
          final v = row[i].trim();
          if (v.isEmpty || _looksLikeMembershipType(v)) continue;
          if (i == (col['nameM'] ?? -1) ||
              i == (col['nameF'] ?? -1) ||
              i == (col['phoneM'] ?? -1) ||
              i == (col['phoneF'] ?? -1) ||
              i == (col['address'] ?? -1) ||
              i == (col['anniversary'] ?? -1) ||
              i == (col['dobM'] ?? -1) ||
              i == (col['dobF'] ?? -1) ||
              i == (col['professionM'] ?? -1) ||
              i == (col['professionF'] ?? -1) ||
              i == (col['type'] ?? -1)) {
            continue;
          }
          // Prefer columns near template proposer index.
          if (i >= 8 && i <= 12 && RegExp(r'[A-Za-z\u0900-\u097F]{2,}').hasMatch(v)) {
            proposer = v;
            break;
          }
        }
      }

      if ([nameM, nameF, phoneM, phoneF].every((e) => e.isEmpty)) {
        skipped++;
        continue;
      }

      var type = MembershipTypeX.fromLabel(typeRaw);
      if (typeRaw.isEmpty) {
        type = (nameM.isNotEmpty && nameF.isNotEmpty)
            ? MembershipType.couple
            : MembershipType.single;
      }

      // Pati / patni = do alag members (linked when both present).
      final idM = MemberStore.newId();
      final idF = MemberStore.newId();
      final ann = _normalizeDate(anniversary);
      var rowAdded = 0;

      if (nameM.isNotEmpty) {
        final m = Member(
          id: idM,
          name: nameM,
          phone: phoneM,
          dob: _normalizeDate(dobM),
          profession: professionM,
          gender: MemberGender.male,
          anniversary: ann,
          address: address,
          proposer: proposer,
          membershipType: nameF.isNotEmpty ? MembershipType.couple : type,
          spouseId: nameF.isNotEmpty ? idF : '',
        );
        if (m.isSane) {
          members.add(m);
          rowAdded++;
        }
      }
      if (nameF.isNotEmpty) {
        final f = Member(
          id: idF,
          name: nameF,
          phone: phoneF,
          dob: _normalizeDate(dobF),
          profession: professionF,
          gender: MemberGender.female,
          anniversary: ann,
          address: address,
          proposer: proposer,
          membershipType: nameM.isNotEmpty ? MembershipType.couple : type,
          spouseId: nameM.isNotEmpty ? idM : '',
        );
        if (f.isSane) {
          members.add(f);
          rowAdded++;
        }
      }
      if (rowAdded == 0) skipped++;
    }

    if (members.isEmpty && rows.length > 1) {
      return (
        const MemberImportResult(
          imported: 0,
          skipped: 0,
          errors: [
            'Valid member rows nahi mile.\n'
                'Shayad galat/binary file thi — CSV ya .xlsx (Export) use karein.',
          ],
        ),
        <Member>[],
      );
    }

    return (
      MemberImportResult(imported: members.length, skipped: skipped),
      members,
    );
  }

  static Map<String, int> _mapHeaderStrings(List<String> headerRow) {
    final map = <String, int>{};
    var dobCount = 0;
    var professionCount = 0;
    var nameCount = 0;

    for (var i = 0; i < headerRow.length; i++) {
      final h = _normHeader(headerRow[i]);
      if (h.isEmpty) continue;

      if (_isNameM(h)) {
        map.putIfAbsent('nameM', () => i);
        nameCount++;
        continue;
      }
      if (_isNameF(h)) {
        map.putIfAbsent('nameF', () => i);
        nameCount++;
        continue;
      }
      if (h.contains('phone') || h == 'phone no' || h.contains('mobile')) {
        if (h.contains('(m)')) {
          map['phoneM'] = i;
        } else if (h.contains('(f)')) {
          map['phoneF'] = i;
        } else if (!map.containsKey('phoneM')) {
          map['phoneM'] = i;
        } else if (!map.containsKey('phoneF')) {
          map['phoneF'] = i;
        }
        continue;
      }
      if (h.contains('dob') || h.contains('birth')) {
        if (h.contains('(m)') || (!map.containsKey('dobM') && dobCount == 0)) {
          map['dobM'] = i;
        } else if (h.contains('(f)') || !map.containsKey('dobF')) {
          map['dobF'] = i;
        }
        dobCount++;
        continue;
      }
      if (h.contains('profes') || h.contains('profeet') || h.contains('occupation')) {
        if (h.contains('(m)') ||
            (!map.containsKey('professionM') && professionCount == 0)) {
          map['professionM'] = i;
        } else if (h.contains('(f)') || !map.containsKey('professionF')) {
          map['professionF'] = i;
        }
        professionCount++;
        continue;
      }
      if (h.contains('anniv') || h.contains('annvars') || h.contains('anivers')) {
        map['anniversary'] = i;
        continue;
      }
      if (h.contains('address') || h.contains('addres')) {
        map['address'] = i;
        continue;
      }
      if (_isProposerHeader(h)) {
        map['proposer'] = i;
        continue;
      }
      if (h.contains('couple') || h.contains('single')) {
        map['type'] = i;
        continue;
      }
      if (h.contains('name') && h.contains('(m)')) {
        map.putIfAbsent('nameM', () => i);
      } else if (h.contains('name') && h.contains('(f)')) {
        map.putIfAbsent('nameF', () => i);
      } else if (h.contains('name') && nameCount == 0) {
        map.putIfAbsent('nameM', () => i);
        nameCount++;
      } else if (h.contains('name')) {
        map.putIfAbsent('nameF', () => i);
      }
    }

    if (map.isEmpty) {
      return {
        'nameM': 0,
        'phoneM': 1,
        'dobM': 2,
        'professionM': 3,
        'nameF': 4,
        'phoneF': 5,
        'dobF': 6,
        'professionF': 7,
        'anniversary': 8,
        'address': 9,
        'proposer': 10,
        'type': 11,
      };
    }
    return map;
  }

  static bool _isNameM(String h) =>
      (h.contains('name') && h.contains('(m)')) ||
      h.contains('lion name (m)') ||
      (h.startsWith('lion name') &&
          !h.contains('(f)') &&
          !h.contains('propos') &&
          !h.contains('propose'));

  static bool _isNameF(String h) =>
      (h.contains('name') && h.contains('(f)')) ||
      h.contains('lion name (f)') ||
      h.contains('lioness');

  static bool _isProposerHeader(String h) {
    if (h.contains('propos') ||
        h.contains('prposer') ||
        h.contains('propose') ||
        h.contains('proposed') ||
        h.contains('sponsor') ||
        h.contains('प्रस्तावक')) {
      // Avoid matching profession columns.
      if (h.contains('profes') || h.contains('occupation')) return false;
      return true;
    }
    return false;
  }

  static bool _looksLikeMembershipType(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return false;
    return t == 'couple' ||
        t == 'single' ||
        t.contains('couple') ||
        t.contains('single') ||
        t.contains('दो') ||
        t == 'c' ||
        t == 's';
  }

  static String _normHeader(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

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

  static String _normalizeDate(String raw) {
    final d = Member.parseFlexibleDate(raw);
    if (d != null) return Member.formatDate(d);
    return raw.trim();
  }
}

/// Backward-compatible alias.
typedef MemberExcelImportResult = MemberImportResult;
