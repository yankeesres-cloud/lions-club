import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum LedgerType { income, expense }

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.note = '',
    this.category = '',
  });

  final String id;
  final LedgerType type;
  final double amount;
  final String date;
  final String note;
  final String category;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'date': date,
        'note': note,
        'category': category,
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
    );
  }
}

class AccountsStore {
  static const _k = 'lions_accounts_v1';
  static List<LedgerEntry> _cache = [];
  static bool _loaded = false;

  static List<LedgerEntry> get current {
    final list = List<LedgerEntry>.of(_cache);
    list.sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(list);
  }

  static double get totalIncome => _cache
      .where((e) => e.type == LedgerType.income)
      .fold(0.0, (a, b) => a + b.amount);

  static double get totalExpense => _cache
      .where((e) => e.type == LedgerType.expense)
      .fold(0.0, (a, b) => a + b.amount);

  static double get balance => totalIncome - totalExpense;

  static Future<List<LedgerEntry>> load() async {
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
          .map((e) => LedgerEntry.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (_) {
      _cache = [];
    }
    _loaded = true;
    return current;
  }

  static Future<List<LedgerEntry>> ensureLoaded() async {
    if (_loaded) return current;
    return load();
  }

  static Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(_cache.map((e) => e.toJson()).toList()));
  }

  static Future<void> upsert(LedgerEntry e) async {
    await ensureLoaded();
    final i = _cache.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      _cache[i] = e;
    } else {
      _cache = [..._cache, e];
    }
    await _persist();
  }

  static Future<void> delete(String id) async {
    await ensureLoaded();
    _cache = _cache.where((e) => e.id != id).toList();
    await _persist();
  }

  static String newId() => 'acc_${DateTime.now().microsecondsSinceEpoch}';
}
