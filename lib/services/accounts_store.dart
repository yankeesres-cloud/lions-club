import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum LedgerType { income, expense }

/// How membership fee / donation was deposited.
enum PaymentMethod {
  cash,
  upi,
  cheque,
  bank,
  other,
}

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.cheque:
        return 'Cheque';
      case PaymentMethod.bank:
        return 'Bank transfer';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  static PaymentMethod fromRaw(String? raw) {
    final t = (raw ?? '').trim().toLowerCase();
    for (final m in PaymentMethod.values) {
      if (m.name == t) return m;
    }
    if (t.contains('upi') || t.contains('gpay') || t.contains('phonepe')) {
      return PaymentMethod.upi;
    }
    if (t.contains('cheque') || t.contains('check')) return PaymentMethod.cheque;
    if (t.contains('bank') || t.contains('neft') || t.contains('rtgs')) {
      return PaymentMethod.bank;
    }
    if (t.contains('cash') || t.contains('नकद')) return PaymentMethod.cash;
    return PaymentMethod.other;
  }
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.note = '',
    this.category = '',
    this.programId = '',
  });

  final String id;
  final LedgerType type;
  final double amount;
  final String date;
  final String note;
  final String category;
  /// Expense program bucket (Treasurer → Expenses).
  final String programId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'date': date,
        'note': note,
        'category': category,
        'programId': programId,
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> j) {
    final t = (j['type'] ?? 'expense').toString();
    return LedgerEntry(
      id: (j['id'] ?? '').toString(),
      type: t == 'income' ? LedgerType.income : LedgerType.expense,
      amount: (j['amount'] is num)
          ? (j['amount'] as num).toDouble()
          : double.tryParse('${j['amount']}') ?? 0,
      date: (j['date'] ?? '').toString(),
      note: (j['note'] ?? '').toString(),
      category: (j['category'] ?? '').toString(),
      programId: (j['programId'] ?? '').toString(),
    );
  }
}

/// Treasurer Expenses — pehle program, phir uske andar kharch.
class ExpenseProgram {
  const ExpenseProgram({
    required this.id,
    required this.name,
    required this.date,
  });

  final String id;
  final String name;
  /// Program date — dd/MM/yyyy
  final String date;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date,
      };

  factory ExpenseProgram.fromJson(Map<String, dynamic> j) {
    return ExpenseProgram(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      date: (j['date'] ?? '').toString(),
    );
  }
}

/// Club-level fee settings (upar fixed amount).
class AccountsFeeSettings {
  const AccountsFeeSettings({
    this.coupleFee = 5000,
    this.singleFee = 3000,
    this.boardFee = 0,
  });

  final double coupleFee;
  final double singleFee;
  final double boardFee;

  AccountsFeeSettings copyWith({
    double? coupleFee,
    double? singleFee,
    double? boardFee,
  }) {
    return AccountsFeeSettings(
      coupleFee: coupleFee ?? this.coupleFee,
      singleFee: singleFee ?? this.singleFee,
      boardFee: boardFee ?? this.boardFee,
    );
  }

  Map<String, dynamic> toJson() => {
        'coupleFee': coupleFee,
        'singleFee': singleFee,
        'boardFee': boardFee,
      };

  factory AccountsFeeSettings.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const AccountsFeeSettings();
    double parse(dynamic v, double fb) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v'.replaceAll(RegExp(r'[^\d.]'), '')) ?? fb;
    }

    return AccountsFeeSettings(
      coupleFee: parse(j['coupleFee'], 5000),
      singleFee: parse(j['singleFee'], 3000),
      boardFee: parse(j['boardFee'], 0),
    );
  }
}

/// Per member (or couple unit) membership fee jama.
class MemberFeeRecord {
  const MemberFeeRecord({
    required this.id,
    required this.memberId,
    this.spouseMemberId = '',
    this.amount = 0,
    this.isCouple = false,
    this.paid = false,
    this.boardPaid = false,
    this.method = PaymentMethod.cash,
    this.paymentDetail = '',
    this.date = '',
    this.note = '',
  });

  final String id;
  /// Primary member for this fee row.
  final String memberId;
  /// If couple unit, second person id.
  final String spouseMemberId;
  final double amount;
  final bool isCouple;
  /// Membership (couple/single) fee jama.
  final bool paid;
  /// Board fee alag — tabhi Board Kul Jama mein count.
  final bool boardPaid;
  final PaymentMethod method;
  /// UPI ref / cheque no / bank txn detail
  final String paymentDetail;
  final String date;
  final String note;

  MemberFeeRecord copyWith({
    String? id,
    String? memberId,
    String? spouseMemberId,
    double? amount,
    bool? isCouple,
    bool? paid,
    bool? boardPaid,
    PaymentMethod? method,
    String? paymentDetail,
    String? date,
    String? note,
  }) {
    return MemberFeeRecord(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      spouseMemberId: spouseMemberId ?? this.spouseMemberId,
      amount: amount ?? this.amount,
      isCouple: isCouple ?? this.isCouple,
      paid: paid ?? this.paid,
      boardPaid: boardPaid ?? this.boardPaid,
      method: method ?? this.method,
      paymentDetail: paymentDetail ?? this.paymentDetail,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'spouseMemberId': spouseMemberId,
        'amount': amount,
        'isCouple': isCouple,
        'paid': paid,
        'boardPaid': boardPaid,
        'method': method.name,
        'paymentDetail': paymentDetail,
        'date': date,
        'note': note,
      };

  factory MemberFeeRecord.fromJson(Map<String, dynamic> j) {
    return MemberFeeRecord(
      id: (j['id'] ?? '').toString(),
      memberId: (j['memberId'] ?? '').toString(),
      spouseMemberId: (j['spouseMemberId'] ?? '').toString(),
      amount: (j['amount'] is num)
          ? (j['amount'] as num).toDouble()
          : double.tryParse('${j['amount']}') ?? 0,
      isCouple: j['isCouple'] == true,
      paid: j['paid'] == true,
      boardPaid: j['boardPaid'] == true,
      method: PaymentMethodX.fromRaw((j['method'] ?? '').toString()),
      paymentDetail: (j['paymentDetail'] ?? j['detail'] ?? '').toString(),
      date: (j['date'] ?? '').toString(),
      note: (j['note'] ?? '').toString(),
    );
  }
}

/// Donation / fellowship / other jama — category label store mein.
class MemberDonation {
  const MemberDonation({
    required this.id,
    required this.memberId,
    required this.amount,
    this.category = 'Donation',
    this.method = PaymentMethod.cash,
    this.paymentDetail = '',
    this.date = '',
    this.note = '',
  });

  final String id;
  final String memberId;
  final double amount;
  /// Donation · Fellowship contribution · Other …
  final String category;
  final PaymentMethod method;
  final String paymentDetail;
  final String date;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'amount': amount,
        'category': category,
        'method': method.name,
        'paymentDetail': paymentDetail,
        'date': date,
        'note': note,
      };

  factory MemberDonation.fromJson(Map<String, dynamic> j) {
    final cat = (j['category'] ?? '').toString().trim();
    return MemberDonation(
      id: (j['id'] ?? '').toString(),
      memberId: (j['memberId'] ?? '').toString(),
      amount: (j['amount'] is num)
          ? (j['amount'] as num).toDouble()
          : double.tryParse('${j['amount']}') ?? 0,
      category: cat.isEmpty ? 'Donation' : cat,
      method: PaymentMethodX.fromRaw((j['method'] ?? '').toString()),
      paymentDetail: (j['paymentDetail'] ?? '').toString(),
      date: (j['date'] ?? '').toString(),
      note: (j['note'] ?? '').toString(),
    );
  }
}

/// Fixed dropdown extras (Membership / Board fee alag).
const memberReceiveCategories = <String>[
  'Donation',
  'Other',
];

/// Board seat holders — alag board fee jama.
const boardMemberBoardFeeKind = 'Board member board fee';

/// Donation amount quick-select options (₹).
const donationAmountChoices = [501.0, 1100.0, 2100.0, 5100.0, 11000.0];

bool isReservedReceiveKind(String name) {
  final t = name.trim().toLowerCase();
  return t.isEmpty ||
      t == 'membership fees' ||
      t == 'donation' ||
      t == 'other' ||
      t == boardMemberBoardFeeKind.toLowerCase();
}

class AccountsStore {
  static const _kLedger = 'lions_accounts_v1';
  static const _kFees = 'lions_member_fees_v1';
  static const _kDonations = 'lions_member_donations_v1';
  static const _kSettings = 'lions_accounts_fee_settings_v1';
  static const _kCustomKinds = 'lions_receive_custom_kinds_v1';
  static const _kExpensePrograms = 'lions_expense_programs_v1';

  static List<LedgerEntry> _ledger = [];
  static List<MemberFeeRecord> _fees = [];
  static List<MemberDonation> _donations = [];
  static List<ExpenseProgram> _expensePrograms = [];
  static List<String> _customKinds = [];
  static AccountsFeeSettings _settings = const AccountsFeeSettings();
  static bool _loaded = false;

  static List<LedgerEntry> get current {
    final list = List<LedgerEntry>.of(_ledger);
    list.sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(list);
  }

  static List<MemberFeeRecord> get fees => List.unmodifiable(_fees);
  static List<MemberDonation> get donations => List.unmodifiable(_donations);
  static List<ExpenseProgram> get expensePrograms {
    final list = List<ExpenseProgram>.of(_expensePrograms);
    list.sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(list);
  }

  static List<String> get customReceiveKinds => List.unmodifiable(_customKinds);
  static AccountsFeeSettings get settings => _settings;

  static ExpenseProgram? expenseProgramById(String id) {
    final t = id.trim();
    if (t.isEmpty) return null;
    for (final p in _expensePrograms) {
      if (p.id == t) return p;
    }
    return null;
  }

  static List<LedgerEntry> expensesForProgram(String programId) {
    final t = programId.trim();
    if (t.isEmpty) return const [];
    final list = _ledger
        .where((e) => e.type == LedgerType.expense && e.programId == t)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static double programExpenseTotal(String programId) =>
      expensesForProgram(programId).fold(0.0, (a, e) => a + e.amount);

  static double get totalIncome {
    final ledgerIn = _ledger
        .where((e) => e.type == LedgerType.income)
        .fold(0.0, (a, b) => a + b.amount);
    final feeIn =
        _fees.where((e) => e.paid).fold(0.0, (a, b) => a + b.amount);
    final donIn = _donations.fold(0.0, (a, b) => a + b.amount);
    return ledgerIn + feeIn + donIn;
  }

  static double get totalExpense => _ledger
      .where((e) => e.type == LedgerType.expense)
      .fold(0.0, (a, b) => a + b.amount);

  static double get balance => totalIncome - totalExpense;

  static double get totalFeesCollected =>
      _fees.where((e) => e.paid).fold(0.0, (a, b) => a + b.amount);

  static double get totalDonations =>
      _donations.fold(0.0, (a, b) => a + b.amount);

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _ledger = _decodeList(p.getString(_kLedger), LedgerEntry.fromJson);
    _fees = _decodeList(p.getString(_kFees), MemberFeeRecord.fromJson);
    _donations =
        _decodeList(p.getString(_kDonations), MemberDonation.fromJson);
    _expensePrograms = _decodeList(
      p.getString(_kExpensePrograms),
      ExpenseProgram.fromJson,
    ).where((e) => e.id.isNotEmpty && e.name.trim().isNotEmpty).toList();
    _customKinds = _decodeStringList(p.getString(_kCustomKinds));
    // Purane donation categories se custom boxes recover.
    final beforeKinds = _customKinds.length;
    for (final d in _donations) {
      _addCustomKindLocal(d.category);
    }
    try {
      final raw = p.getString(_kSettings);
      if (raw != null && raw.isNotEmpty) {
        _settings = AccountsFeeSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } else {
        _settings = const AccountsFeeSettings();
      }
    } catch (_) {
      _settings = const AccountsFeeSettings();
    }
    // Blank / zero fees avoid — defaults bhar do
    if (_settings.coupleFee <= 0 || _settings.singleFee <= 0) {
      _settings = AccountsFeeSettings(
        coupleFee: _settings.coupleFee > 0 ? _settings.coupleFee : 5000,
        singleFee: _settings.singleFee > 0 ? _settings.singleFee : 3000,
        boardFee: _settings.boardFee,
      );
      await p.setString(_kSettings, jsonEncode(_settings.toJson()));
    }
    if (_customKinds.length != beforeKinds) {
      await _persistCustomKinds();
    }
    _loaded = true;
  }

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  static List<T> _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .where((e) {
            if (e is LedgerEntry) return e.id.isNotEmpty;
            if (e is MemberFeeRecord) return e.id.isNotEmpty;
            if (e is MemberDonation) return e.id.isNotEmpty;
            if (e is ExpenseProgram) {
              return e.id.isNotEmpty && e.name.trim().isNotEmpty;
            }
            return true;
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _persistExpensePrograms() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kExpensePrograms,
      jsonEncode(_expensePrograms.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> _persistLedger() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kLedger,
      jsonEncode(_ledger.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> _persistFees() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kFees,
      jsonEncode(_fees.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> _persistDonations() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kDonations,
      jsonEncode(_donations.map((e) => e.toJson()).toList()),
    );
  }

  static List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty && !isReservedReceiveKind(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _persistCustomKinds() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kCustomKinds, jsonEncode(_customKinds));
  }

  static void _addCustomKindLocal(String name) {
    final t = name.trim();
    if (isReservedReceiveKind(t)) return;
    final exists = _customKinds.any(
      (e) => e.toLowerCase() == t.toLowerCase(),
    );
    if (exists) return;
    _customKinds = [..._customKinds, t];
  }

  /// Other se naya naam — upar chip/box ke liye save.
  static Future<void> rememberReceiveKind(String name) async {
    await ensureLoaded();
    final before = _customKinds.length;
    _addCustomKindLocal(name);
    if (_customKinds.length != before) await _persistCustomKinds();
  }

  static Future<void> saveSettings(AccountsFeeSettings s) async {
    await ensureLoaded();
    _settings = s;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSettings, jsonEncode(s.toJson()));
  }

  static Future<void> upsert(LedgerEntry e) async {
    await ensureLoaded();
    final i = _ledger.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      _ledger[i] = e;
    } else {
      _ledger = [..._ledger, e];
    }
    await _persistLedger();
  }

  static Future<void> delete(String id) async {
    await ensureLoaded();
    _ledger = _ledger.where((e) => e.id != id).toList();
    await _persistLedger();
  }

  static Future<void> upsertExpenseProgram(ExpenseProgram e) async {
    await ensureLoaded();
    final i = _expensePrograms.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      _expensePrograms[i] = e;
    } else {
      _expensePrograms = [..._expensePrograms, e];
    }
    await _persistExpensePrograms();
  }

  /// Program + uske andar ke expenses delete.
  static Future<void> deleteExpenseProgram(String id) async {
    await ensureLoaded();
    final t = id.trim();
    if (t.isEmpty) return;
    _expensePrograms = _expensePrograms.where((e) => e.id != t).toList();
    _ledger = _ledger.where((e) => e.programId != t).toList();
    await _persistExpensePrograms();
    await _persistLedger();
  }

  static Future<void> upsertFee(MemberFeeRecord e) async {
    await ensureLoaded();
    final i = _fees.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      _fees[i] = e;
    } else {
      _fees = [..._fees, e];
    }
    await _persistFees();
  }

  static Future<void> deleteFee(String id) async {
    await ensureLoaded();
    _fees = _fees.where((e) => e.id != id).toList();
    await _persistFees();
  }

  static MemberFeeRecord? feeForMember(String memberId) {
    final id = memberId.trim();
    if (id.isEmpty) return null;
    for (final f in _fees) {
      if (f.memberId == id || f.spouseMemberId == id) return f;
    }
    return null;
  }

  static Future<void> upsertDonation(MemberDonation e) async {
    await ensureLoaded();
    final i = _donations.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      _donations[i] = e;
    } else {
      _donations = [..._donations, e];
    }
    await _persistDonations();
    await rememberReceiveKind(e.category);
  }

  static Future<void> deleteDonation(String id) async {
    await ensureLoaded();
    _donations = _donations.where((e) => e.id != id).toList();
    await _persistDonations();
  }

  static String newId() => 'acc_${DateTime.now().microsecondsSinceEpoch}';
  static String newFeeId() => 'fee_${DateTime.now().microsecondsSinceEpoch}';
  static String newExpenseProgramId() =>
      'eprog_${DateTime.now().microsecondsSinceEpoch}';
  static String newDonationId() =>
      'don_${DateTime.now().microsecondsSinceEpoch}';
}
