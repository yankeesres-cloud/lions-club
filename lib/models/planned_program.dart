import '../models/member.dart';

class ProgramChecklistItem {
  const ProgramChecklistItem({
    required this.id,
    required this.title,
    this.done = false,
  });

  final String id;
  final String title;
  final bool done;

  ProgramChecklistItem copyWith({String? id, String? title, bool? done}) {
    return ProgramChecklistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      done: done ?? this.done,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
      };

  factory ProgramChecklistItem.fromJson(Map<String, dynamic> j) {
    return ProgramChecklistItem(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      done: j['done'] == true,
    );
  }
}

class PlannedProgram {
  const PlannedProgram({
    required this.id,
    required this.title,
    this.expectedDate = '',
    this.expectedTime = '',
    this.place = '',
    this.notes = '',
    this.pcMemberIds = const [],
    this.directorMemberId = '',
    this.directorVpLevel = 0,
    this.planMonth = 0,
    this.planYear = 0,
    this.estimatedBudget = 0,
    this.checklist = const [],
    this.attendedMemberIds = const [],
  });

  static const maxPcs = 4;

  final String id;
  final String title;
  /// Anumanit date — dd/MM/yyyy
  final String expectedDate;
  final String expectedTime;
  final String place;
  final String notes;
  /// Program PCs — 1 se 4 [Member.id]
  final List<String> pcMemberIds;
  /// Ek hi Program Director — [Member.id]
  final String directorMemberId;
  /// Director ka VP level: 1 / 2 / 3 (0 = unset)
  final int directorVpLevel;
  /// 1–12; 0 = derive from expectedDate
  final int planMonth;
  /// e.g. 2026; 0 = derive / current
  final int planYear;
  /// Anumanit budget (₹)
  final double estimatedBudget;
  final List<ProgramChecklistItem> checklist;
  /// Program mein hazir members — star rating ke liye.
  final List<String> attendedMemberIds;

  bool get hasPc => pcMemberIds.any((e) => e.trim().isNotEmpty);
  bool get hasDirector =>
      directorMemberId.trim().isNotEmpty &&
      directorVpLevel >= 1 &&
      directorVpLevel <= 3;

  String get directorVpLabel {
    if (directorVpLevel == 1) return 'VP-1';
    if (directorVpLevel == 2) return 'VP-2';
    if (directorVpLevel == 3) return 'VP-3';
    return 'VP';
  }

  /// Normalized unique PC ids (max 4).
  List<String> get pcsNormalized {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in pcMemberIds) {
      final id = raw.trim();
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      out.add(id);
      if (out.length >= maxPcs) break;
    }
    return out;
  }

  static const monthLabels = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  int get resolvedMonth {
    if (planMonth >= 1 && planMonth <= 12) return planMonth;
    final d = expectedDateTime;
    if (d != null) return d.month;
    return 0;
  }

  int get resolvedYear {
    if (planYear >= 2000 && planYear <= 2100) return planYear;
    final d = expectedDateTime;
    if (d != null) return d.year;
    return DateTime.now().year;
  }

  String get monthYearLabel {
    final m = resolvedMonth;
    final y = resolvedYear;
    if (m < 1 || m > 12) return 'Month TBD';
    return '${monthLabels[m - 1]} $y';
  }

  String get budgetLabel {
    if (estimatedBudget <= 0) return '—';
    if (estimatedBudget == estimatedBudget.roundToDouble()) {
      return '₹${estimatedBudget.round()}';
    }
    return '₹${estimatedBudget.toStringAsFixed(0)}';
  }

  DateTime? get expectedDateTime => Member.parseFlexibleDate(expectedDate);

  DateTime? get expectedDateTimeWithTime {
    final d = expectedDateTime;
    if (d == null) return null;
    final t = expectedTime.trim();
    if (t.isEmpty) return d;
    final parts = t.split(':');
    if (parts.length < 2) return d;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return DateTime(d.year, d.month, d.day, h, m);
  }

  String get dateTimeLabel {
    final d = expectedDate.trim().isEmpty ? 'Date TBD' : expectedDate.trim();
    final t = expectedTime.trim();
    if (t.isEmpty) return d;
    return '$d · $t';
  }

  bool get isUpcoming {
    final d = expectedDateTime;
    if (d == null) return true;
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final prog = DateTime(d.year, d.month, d.day);
    return !prog.isBefore(day);
  }

  bool get isInReminderWindow {
    final d = expectedDateTime;
    if (d == null) return false;
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final prog = DateTime(d.year, d.month, d.day);
    if (prog.isBefore(day)) return false;
    final start = prog.subtract(const Duration(days: 10));
    return !day.isBefore(start);
  }

  int? get daysUntil {
    final d = expectedDateTime;
    if (d == null) return null;
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final prog = DateTime(d.year, d.month, d.day);
    return prog.difference(day).inDays;
  }

  int get checklistDoneCount => checklist.where((c) => c.done).length;
  int get checklistTotal => checklist.length;

  List<String> get attendanceNormalized {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in attendedMemberIds) {
      final id = raw.trim();
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      out.add(id);
    }
    return out;
  }

  PlannedProgram copyWith({
    String? id,
    String? title,
    String? expectedDate,
    String? expectedTime,
    String? place,
    String? notes,
    List<String>? pcMemberIds,
    String? directorMemberId,
    int? directorVpLevel,
    int? planMonth,
    int? planYear,
    double? estimatedBudget,
    List<ProgramChecklistItem>? checklist,
    List<String>? attendedMemberIds,
    bool clearPcs = false,
    bool clearDirector = false,
  }) {
    return PlannedProgram(
      id: id ?? this.id,
      title: title ?? this.title,
      expectedDate: expectedDate ?? this.expectedDate,
      expectedTime: expectedTime ?? this.expectedTime,
      place: place ?? this.place,
      notes: notes ?? this.notes,
      pcMemberIds: clearPcs ? const [] : (pcMemberIds ?? this.pcMemberIds),
      directorMemberId:
          clearDirector ? '' : (directorMemberId ?? this.directorMemberId),
      directorVpLevel:
          clearDirector ? 0 : (directorVpLevel ?? this.directorVpLevel),
      planMonth: planMonth ?? this.planMonth,
      planYear: planYear ?? this.planYear,
      estimatedBudget: estimatedBudget ?? this.estimatedBudget,
      checklist: checklist ?? this.checklist,
      attendedMemberIds: attendedMemberIds ?? this.attendedMemberIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'expectedDate': expectedDate,
        'expectedTime': expectedTime,
        'place': place,
        'notes': notes,
        'pcMemberIds': pcsNormalized,
        // legacy single-pc for older readers
        'pcMemberId': pcsNormalized.isEmpty ? '' : pcsNormalized.first,
        'directorMemberId': directorMemberId,
        'directorVpLevel': directorVpLevel,
        'planMonth': planMonth,
        'planYear': planYear,
        'estimatedBudget': estimatedBudget,
        'checklist': checklist.map((e) => e.toJson()).toList(),
        'attendedMemberIds': attendanceNormalized,
      };

  factory PlannedProgram.fromJson(Map<String, dynamic> j) {
    final rawList = j['checklist'];
    final items = <ProgramChecklistItem>[];
    if (rawList is List) {
      for (final e in rawList.whereType<Map>()) {
        final item = ProgramChecklistItem.fromJson(Map<String, dynamic>.from(e));
        if (item.id.isNotEmpty && item.title.trim().isNotEmpty) {
          items.add(item);
        }
      }
    }
    final budgetRaw = j['estimatedBudget'] ?? j['budget'];
    double budget = 0;
    if (budgetRaw is num) {
      budget = budgetRaw.toDouble();
    } else {
      budget = double.tryParse(
            (budgetRaw ?? '').toString().replaceAll(RegExp(r'[^\d.]'), ''),
          ) ??
          0;
    }

    final pcs = <String>[];
    final seen = <String>{};
    void addPc(String? raw) {
      final id = (raw ?? '').trim();
      if (id.isEmpty || seen.contains(id)) return;
      seen.add(id);
      pcs.add(id);
    }

    final rawPcs = j['pcMemberIds'];
    if (rawPcs is List) {
      for (final e in rawPcs) {
        addPc(e.toString());
      }
    }
    addPc((j['pcMemberId'] ?? j['pc'] ?? '').toString());
    addPc((j['pc2'] ?? '').toString());
    addPc((j['pc3'] ?? '').toString());
    addPc((j['pc4'] ?? '').toString());

    var directorId = (j['directorMemberId'] ?? j['director'] ?? '').toString();
    var vpLevel = (j['directorVpLevel'] is int)
        ? j['directorVpLevel'] as int
        : int.tryParse('${j['directorVpLevel'] ?? j['directorVp'] ?? ''}') ?? 0;

    // Legacy: alag VP1/VP2/VP3 → pehla non-empty director
    if (directorId.trim().isEmpty) {
      final v1 = (j['directorVp1Id'] ?? j['vp1'] ?? '').toString().trim();
      final v2 = (j['directorVp2Id'] ?? j['vp2'] ?? '').toString().trim();
      final v3 = (j['directorVp3Id'] ?? j['vp3'] ?? '').toString().trim();
      if (v1.isNotEmpty) {
        directorId = v1;
        vpLevel = 1;
      } else if (v2.isNotEmpty) {
        directorId = v2;
        vpLevel = 2;
      } else if (v3.isNotEmpty) {
        directorId = v3;
        vpLevel = 3;
      }
    }
    if (vpLevel < 0 || vpLevel > 3) vpLevel = 0;

    final attended = <String>[];
    final seenAtt = <String>{};
    final rawAtt = j['attendedMemberIds'] ?? j['attendance'];
    if (rawAtt is List) {
      for (final e in rawAtt) {
        final id = e.toString().trim();
        if (id.isEmpty || seenAtt.contains(id)) continue;
        seenAtt.add(id);
        attended.add(id);
      }
    }

    return PlannedProgram(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      expectedDate: (j['expectedDate'] ?? j['date'] ?? '').toString(),
      expectedTime: (j['expectedTime'] ?? j['time'] ?? '').toString(),
      place: (j['place'] ?? j['venue'] ?? '').toString(),
      notes: (j['notes'] ?? '').toString(),
      pcMemberIds: pcs.take(maxPcs).toList(),
      directorMemberId: directorId,
      directorVpLevel: vpLevel,
      planMonth: (j['planMonth'] is int)
          ? j['planMonth'] as int
          : int.tryParse('${j['planMonth'] ?? ''}') ?? 0,
      planYear: (j['planYear'] is int)
          ? j['planYear'] as int
          : int.tryParse('${j['planYear'] ?? ''}') ?? 0,
      estimatedBudget: budget,
      checklist: items.isEmpty ? defaultChecklist() : items,
      attendedMemberIds: attended,
    );
  }

  static List<ProgramChecklistItem> defaultChecklist() {
    const titles = [
      'Venue confirm',
      'Date & time finalize',
      'PC / team brief',
      'Guest / speaker confirm',
      'Invitation / WhatsApp',
      'Banner / backdrop',
      'Sound / mike',
      'Photography',
      'Attendance sheet',
      'Budget / accounts',
      'Certificates / memento',
      'Report / photos upload',
    ];
    return [
      for (var i = 0; i < titles.length; i++)
        ProgramChecklistItem(id: 'chk_$i', title: titles[i]),
    ];
  }

  static int? parseMonth(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return null;
    final asNum = int.tryParse(t);
    if (asNum != null && asNum >= 1 && asNum <= 12) return asNum;
    for (var i = 0; i < monthLabels.length; i++) {
      final m = monthLabels[i].toLowerCase();
      if (t == m || t.startsWith(m.substring(0, 3))) return i + 1;
    }
    const hi = {
      'jan': 1,
      'january': 1,
      'जनवरी': 1,
      'feb': 2,
      'february': 2,
      'फरवरी': 2,
      'mar': 3,
      'march': 3,
      'मार्च': 3,
      'apr': 4,
      'april': 4,
      'अप्रैल': 4,
      'may': 5,
      'मई': 5,
      'jun': 6,
      'june': 6,
      'जून': 6,
      'jul': 7,
      'july': 7,
      'जुलाई': 7,
      'aug': 8,
      'august': 8,
      'अगस्त': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'सितंबर': 9,
      'oct': 10,
      'october': 10,
      'अक्टूबर': 10,
      'nov': 11,
      'november': 11,
      'नवंबर': 11,
      'dec': 12,
      'december': 12,
      'दिसंबर': 12,
    };
    return hi[t];
  }
}
