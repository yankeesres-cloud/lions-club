import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/member.dart';
import '../../services/accounts_store.dart';
import '../../services/board_store.dart';
import '../../services/club_settings_store.dart';
import '../../services/member_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/member_picker.dart';

class _JamaListRow {
  const _JamaListRow({
    required this.name,
    required this.amount,
    this.date = '',
    this.method = '',
    this.detail = '',
    this.note = '',
  });

  final String name;
  final double amount;
  final String date;
  final String method;
  final String detail;
  final String note;
}

/// Jama list — alag page taaki TabBar / dialog layout hang na kare.
class _JamaListPage extends StatelessWidget {
  const _JamaListPage({
    required this.title,
    required this.rows,
    required this.totalLabel,
    this.onPrint,
  });

  final String title;
  final List<_JamaListRow> rows;
  final String totalLabel;
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (onPrint != null)
            IconButton(
              tooltip: 'Print preview',
              onPressed: onPrint,
              icon: const Icon(Icons.print_outlined),
            ),
        ],
      ),
      body: rows.isEmpty
          ? Center(
              child: Text(
                'Abhi koi jama nahi',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: rows.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                    child: Text(
                      '${rows.length} log · $totalLabel',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  );
                }
                final r = rows[i - 1];
                final sub = [
                  if (r.date.trim().isNotEmpty) r.date,
                  if (r.method.trim().isNotEmpty) r.method,
                  if (r.detail.trim().isNotEmpty) r.detail,
                  if (r.note.trim().isNotEmpty) r.note,
                ].join(' · ');
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.purple.withValues(alpha: 0.12),
                    child: Text(
                      '$i',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.purple,
                      ),
                    ),
                  ),
                  title: Text(
                    r.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: sub.isEmpty ? null : Text(sub),
                  trailing: Text(
                    '₹${r.amount.round()}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.green.shade700,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// In-app print preview — browser file fail ho to bhi yahan dikhe.
class _JamaPrintPreviewPage extends StatelessWidget {
  const _JamaPrintPreviewPage({
    required this.club,
    required this.title,
    required this.rows,
    required this.onOpenExternal,
  });

  final String club;
  final String title;
  final List<_JamaListRow> rows;
  final Future<void> Function() onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold(0.0, (a, r) => a + r.amount);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Print preview'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              try {
                await onOpenExternal();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Browser khula — Cmd+P se print'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Browser: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.open_in_browser, color: Colors.white),
            label: const Text(
              'Browser Print',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            club,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$title — ${rows.length} log · ₹${total.round()}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          Table(
            border: TableBorder.all(color: Colors.grey.shade400),
            columnWidths: const {
              0: FixedColumnWidth(36),
              1: FlexColumnWidth(2.2),
              2: FlexColumnWidth(1.2),
              3: FlexColumnWidth(1.1),
              4: FlexColumnWidth(1.1),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF3EEF8)),
                children: [
                  for (final h in ['#', 'Name', 'Date', 'Mode', '₹'])
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        h,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
              for (var i = 0; i < rows.length; i++)
                TableRow(
                  children: [
                    _cell('${i + 1}'),
                    _cell(rows[i].name),
                    _cell(rows[i].date),
                    _cell(rows[i].method),
                    _cell('₹${rows[i].amount.round()}', end: true),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Kul: ₹${total.round()}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 20),
          Text(
            'Upar “Browser Print” dabao, phir browser mein Cmd+P / Print.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  static Widget _cell(String text, {bool end = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: end ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontSize: 12.5),
      ),
    );
  }
}

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({
    super.key,
    this.embedded = false,
    /// false = sirf dekhna (Accounts module). Edit sirf Treasurer Work se.
    this.canEdit = false,
    /// Ledger Jama/Kharch block — Received tab mein usually band.
    this.showLedger = true,
  });

  final bool embedded;
  final bool canEdit;
  final bool showLedger;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _FeeUnit {
  const _FeeUnit({
    required this.primary,
    this.spouse,
    required this.isCouple,
    this.boardTitles = const [],
  });

  final Member primary;
  final Member? spouse;
  final bool isCouple;
  /// Board posts held by primary and/or spouse.
  final List<String> boardTitles;

  bool get isBoard => boardTitles.isNotEmpty;

  String get title {
    if (spouse != null) {
      return '${primary.displayName} + ${spouse!.displayName}';
    }
    return primary.displayName;
  }

  String get spouseLine {
    if (spouse == null) return '';
    return 'Patni: ${spouse!.displayName}';
  }

  String get subtitle {
    final parts = <String>[
      if (isCouple) 'Couple fees' else 'Single fees',
      if (isBoard) 'Board fees',
    ];
    return parts.join(' + ');
  }

  /// Sirf membership (couple/single) — board alag.
  double membershipAmount(AccountsFeeSettings s) =>
      isCouple ? s.coupleFee : s.singleFee;

  /// List / dialog default: membership (+ board display ke liye helper).
  double defaultAmount(AccountsFeeSettings s) => membershipAmount(s);

  double totalDue(AccountsFeeSettings s) {
    final base = membershipAmount(s);
    if (isBoard && s.boardFee > 0) return base + s.boardFee;
    return base;
  }

  String amountBreakdown(AccountsFeeSettings s) {
    final base = membershipAmount(s);
    final baseLabel = isCouple ? 'Couple' : 'Single';
    if (isBoard && s.boardFee > 0) {
      return '$baseLabel ₹${base.round()} + Board ₹${s.boardFee.round()}';
    }
    return '$baseLabel ₹${base.round()}';
  }
}

class _AccountsScreenState extends State<AccountsScreen> {
  bool _loading = true;
  List<LedgerEntry> _entries = [];
  List<Member> _members = [];
  List<_FeeUnit> _units = [];
  List<MemberDonation> _donations = [];
  AccountsFeeSettings _settings = const AccountsFeeSettings();
  final _coupleFeeCtrl = TextEditingController();
  final _singleFeeCtrl = TextEditingController();
  final _boardFeeCtrl = TextEditingController();
  /// Fixed fees mostly locked — Edit se khulte hain, Save se band.
  bool _feesEditing = false;
  /// Members list mein sirf pending (baki) fees.
  bool _showPendingOnly = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _coupleFeeCtrl.dispose();
    _singleFeeCtrl.dispose();
    _boardFeeCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    await AccountsStore.ensureLoaded();
    await BoardStore.ensureLoaded();
    final members = await MemberStore.ensureLoaded();
    if (!mounted) return;
    final settings = AccountsStore.settings;
    setState(() {
      _entries = AccountsStore.current;
      _members = members;
      _units = _buildUnits(members);
      _donations = List.of(AccountsStore.donations)
        ..sort((a, b) => b.date.compareTo(a.date));
      _settings = settings;
      // Controllers hamesha number dikhayein — blank mat chhodo
      _coupleFeeCtrl.text = (settings.coupleFee > 0 ? settings.coupleFee : 5000)
          .round()
          .toString();
      _singleFeeCtrl.text = (settings.singleFee > 0 ? settings.singleFee : 3000)
          .round()
          .toString();
      _boardFeeCtrl.text = settings.boardFee.round().toString();
      _loading = false;
    });
  }

  List<String> _boardTitlesFor(Member a, [Member? b]) {
    final titles = <String>[];
    final seen = <String>{};
    void addAll(String memberId) {
      for (final p in BoardStore.postsForMember(memberId)) {
        final t = p.title.trim();
        if (t.isEmpty || seen.contains(t)) continue;
        seen.add(t);
        titles.add(t);
      }
    }

    addAll(a.id);
    if (b != null) addAll(b.id);
    return titles;
  }

  List<_FeeUnit> _buildUnits(List<Member> members) {
    final byId = {for (final m in members) m.id: m};
    final seen = <String>{};
    final units = <_FeeUnit>[];

    Member? resolveSpouse(Member m) {
      if (!m.hasSpouse || m.spouseId == m.id) return null;
      final s = byId[m.spouseId] ?? MemberStore.byId(m.spouseId);
      if (s == null || s.id == m.id) return null;
      return s;
    }

    _FeeUnit coupleUnit(Member a, Member b) {
      // Husband pehle, patni saath
      late final Member husband;
      late final Member wife;
      if (a.gender == MemberGender.male && b.gender == MemberGender.female) {
        husband = a;
        wife = b;
      } else if (b.gender == MemberGender.male && a.gender == MemberGender.female) {
        husband = b;
        wife = a;
      } else {
        husband = a;
        wife = b;
      }
      return _FeeUnit(
        primary: husband,
        spouse: wife,
        isCouple: true,
        boardTitles: _boardTitlesFor(husband, wife),
      );
    }

    // 1) Explicit spouseId couples
    for (final m in members) {
      if (seen.contains(m.id)) continue;
      final spouse = resolveSpouse(m);
      if (spouse == null) continue;
      seen.add(m.id);
      seen.add(spouse.id);
      units.add(coupleUnit(m, spouse));
    }

    // 2) Couple-type leftovers — pair M+F by shared anniversary / address
    final leftover = members.where((m) => !seen.contains(m.id)).toList();
    final used = <String>{};
    for (final m in leftover) {
      if (used.contains(m.id) || seen.contains(m.id)) continue;
      if (m.membershipType != MembershipType.couple &&
          m.gender != MemberGender.male) {
        continue;
      }
      Member? match;
      for (final o in leftover) {
        if (o.id == m.id || used.contains(o.id) || seen.contains(o.id)) {
          continue;
        }
        if (m.gender == o.gender) continue;
        final ann =
            m.anniversary.trim().isNotEmpty &&
            m.anniversary.trim() == o.anniversary.trim();
        final addr = m.address.trim().isNotEmpty &&
            m.address.trim().toLowerCase() == o.address.trim().toLowerCase();
        if (ann || addr) {
          match = o;
          break;
        }
      }
      if (match != null) {
        used.add(m.id);
        used.add(match.id);
        seen.add(m.id);
        seen.add(match.id);
        units.add(coupleUnit(m, match));
      }
    }

    // 3) Remaining individuals
    for (final m in members) {
      if (seen.contains(m.id)) continue;
      seen.add(m.id);
      units.add(
        _FeeUnit(
          primary: m,
          isCouple: m.membershipType == MembershipType.couple,
          boardTitles: _boardTitlesFor(m),
        ),
      );
    }

    units.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return units;
  }

  String _today() {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2, '0')}/${n.month.toString().padLeft(2, '0')}/${n.year}';
  }

  String _money(double v) => '₹${v.round()}';

  /// Record amount se membership hissa — purane base+board amounts ko strip.
  double _membershipFromRecord(_FeeUnit u, MemberFeeRecord? rec) {
    final base = u.membershipAmount(_settings);
    if (rec == null || rec.amount <= 0) return base;
    if (u.isBoard && _settings.boardFee > 0) {
      final withBoard = base + _settings.boardFee;
      if ((rec.amount - withBoard).abs() < 0.5) return base;
      final stripped = rec.amount - _settings.boardFee;
      if (stripped > 0 && (stripped - base).abs() < 0.5) return base;
    }
    return rec.amount;
  }

  double get _feesExpected {
    var total = 0.0;
    for (final u in _units) {
      total += u.membershipAmount(_settings);
    }
    return total;
  }

  double get _boardExpected {
    if (_settings.boardFee <= 0) return 0;
    return _units.where((u) => u.isBoard).length * _settings.boardFee;
  }

  double get _boardJama {
    if (_settings.boardFee <= 0) return 0;
    var total = 0.0;
    for (final u in _units.where((e) => e.isBoard)) {
      final rec = AccountsStore.feeForMember(u.primary.id);
      // Sirf jab board alag se jama mark ho — membership paid se nahi.
      if (rec?.boardPaid == true) total += _settings.boardFee;
    }
    return total;
  }

  double get _boardBaki {
    final v = _boardExpected - _boardJama;
    return v < 0 ? 0 : v;
  }

  double get _feesJama {
    var total = 0.0;
    for (final u in _units) {
      final rec = AccountsStore.feeForMember(u.primary.id);
      if (rec?.paid != true) continue;
      total += _membershipFromRecord(u, rec);
    }
    return total;
  }

  double get _feesBaki {
    var total = 0.0;
    for (final u in _units) {
      final rec = AccountsStore.feeForMember(u.primary.id);
      if (rec?.paid == true) continue;
      total += _membershipFromRecord(u, rec);
    }
    return total;
  }

  /// Ledger kharch jisme Board category ho.
  double get _boardKharch {
    var total = 0.0;
    for (final e in _entries) {
      if (e.type != LedgerType.expense) continue;
      final c = e.category.toLowerCase();
      if (c.contains('board') || c.contains('बोर')) {
        total += e.amount;
      }
    }
    return total;
  }

  /// Club kharch = total expense minus board category.
  double get _clubKharch {
    final v = AccountsStore.totalExpense - _boardKharch;
    return v < 0 ? 0 : v;
  }

  double get _ledgerJama => _entries
      .where((e) => e.type == LedgerType.income)
      .fold(0.0, (a, b) => a + b.amount);

  /// Club: membership jama + donation + ledger jama − club kharch.
  double get _clubBalance =>
      (_feesJama + AccountsStore.totalDonations + _ledgerJama) - _clubKharch;

  /// Board: board fee jama − board kharch.
  double get _boardBalance => _boardJama - _boardKharch;

  bool _unitPending(_FeeUnit u, MemberFeeRecord? rec) {
    if (rec?.paid != true) return true;
    if (u.isBoard && _settings.boardFee > 0 && rec?.boardPaid != true) {
      return true;
    }
    return false;
  }

  int get _pendingCount {
    var n = 0;
    for (final u in _units) {
      final rec = AccountsStore.feeForMember(u.primary.id);
      if (_unitPending(u, rec)) n++;
    }
    return n;
  }

  List<_FeeUnit> get _visibleUnits {
    if (!_showPendingOnly) return _units;
    return _units.where((u) {
      final rec = AccountsStore.feeForMember(u.primary.id);
      return _unitPending(u, rec);
    }).toList();
  }

  /// Unit (primary + spouse) — category-wise donation / other.
  Map<String, double> _donationBreakdownForUnit(_FeeUnit u) {
    final ids = <String>{
      u.primary.id,
      if (u.spouse != null) u.spouse!.id,
    };
    final map = <String, double>{};
    for (final d in _donations) {
      if (!ids.contains(d.memberId)) continue;
      final cat = d.category.trim().isEmpty ? 'Donation' : d.category.trim();
      map[cat] = (map[cat] ?? 0) + d.amount;
    }
    return map;
  }

  double _donationsForUnit(_FeeUnit u) =>
      _donationBreakdownForUnit(u).values.fold(0.0, (a, b) => a + b);

  /// Donation pehle, phir baaki categories (Food for Hunger …).
  List<MapEntry<String, double>> _donationLinesForUnit(_FeeUnit u) {
    final entries = _donationBreakdownForUnit(u).entries.toList();
    entries.sort((a, b) {
      final ad = a.key.toLowerCase() == 'donation';
      final bd = b.key.toLowerCase() == 'donation';
      if (ad && !bd) return -1;
      if (!ad && bd) return 1;
      return a.key.toLowerCase().compareTo(b.key.toLowerCase());
    });
    return entries;
  }

  Map<String, double> get _donationTotalsByCategory {
    final map = <String, double>{};
    for (final d in _donations) {
      final cat = d.category.trim().isEmpty ? 'Donation' : d.category.trim();
      map[cat] = (map[cat] ?? 0) + d.amount;
    }
    return map;
  }

  /// Summary boxes: Donation hamesha + Other kinds jo bante jayein.
  List<String> get _receiveAmountBoxLabels {
    final labels = <String>['Donation'];
    final seen = <String>{'donation'};
    void add(String raw) {
      final t = raw.trim();
      if (t.isEmpty) return;
      final key = t.toLowerCase();
      if (key == 'other' || seen.contains(key)) return;
      seen.add(key);
      labels.add(t);
    }

    for (final c in AccountsStore.customReceiveKinds) {
      add(c);
    }
    for (final c in _donationTotalsByCategory.keys) {
      add(c);
    }
    return labels;
  }

  double _amountForReceiveLabel(String label) {
    var n = 0.0;
    final key = label.toLowerCase();
    for (final e in _donationTotalsByCategory.entries) {
      if (e.key.toLowerCase() == key) n += e.value;
    }
    return n;
  }

  List<Widget> _receiveAmountBoxRows() {
    final labels = _receiveAmountBoxLabels;
    final rows = <Widget>[];
    for (var i = 0; i < labels.length; i += 3) {
      final chunk = labels.skip(i).take(3).toList();
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
          child: Row(
            children: [
              for (var j = 0; j < chunk.length; j++) ...[
                if (j > 0) const SizedBox(width: 6),
                Expanded(
                  child: _sumCard(
                    chunk[j],
                    _amountForReceiveLabel(chunk[j]),
                    Colors.teal.shade700,
                    onTap: () => _showJamaList(
                      title: chunk[j],
                      rows: _donationJamaRows(chunk[j]),
                    ),
                  ),
                ),
              ],
              // Row incomplete → empty spacers so cards size match.
              for (var j = chunk.length; j < 3; j++) ...[
                const SizedBox(width: 6),
                const Expanded(child: SizedBox.shrink()),
              ],
            ],
          ),
        ),
      );
    }
    return rows;
  }

  List<_JamaListRow> _kulJamaClubRows() {
    final rows = <_JamaListRow>[];
    for (final u in _units) {
      final rec = AccountsStore.feeForMember(u.primary.id);
      if (rec?.paid != true) continue;
      final amt = _membershipFromRecord(u, rec);
      rows.add(
        _JamaListRow(
          name: u.title,
          amount: amt,
          date: rec?.date ?? '',
          method: rec?.method.label ?? '',
          detail: rec?.paymentDetail ?? '',
        ),
      );
    }
    rows.sort((a, b) => b.amount.compareTo(a.amount));
    return rows;
  }

  List<_JamaListRow> _boardKulJamaRows() {
    final rows = <_JamaListRow>[];
    if (_settings.boardFee <= 0) return rows;
    for (final u in _units.where((e) => e.isBoard)) {
      final rec = AccountsStore.feeForMember(u.primary.id);
      if (rec?.boardPaid != true) continue;
      rows.add(
        _JamaListRow(
          name: u.boardTitles.isEmpty
              ? u.title
              : '${u.title} (${u.boardTitles.join(", ")})',
          amount: _settings.boardFee,
          date: rec?.date ?? '',
          method: rec?.method.label ?? '',
          detail: rec?.paymentDetail ?? '',
        ),
      );
    }
    rows.sort((a, b) => a.name.compareTo(b.name));
    return rows;
  }

  List<_JamaListRow> _donationJamaRows(String categoryLabel) {
    final key = categoryLabel.toLowerCase();
    final rows = <_JamaListRow>[];
    for (final d in _donations) {
      final cat = d.category.trim().isEmpty ? 'Donation' : d.category.trim();
      if (cat.toLowerCase() != key) continue;
      final m = _memberOf(d.memberId);
      rows.add(
        _JamaListRow(
          name: m?.displayName.trim().isNotEmpty == true
              ? m!.displayName
              : 'Member',
          amount: d.amount,
          date: d.date,
          method: d.method.label,
          detail: d.paymentDetail,
          note: d.note,
        ),
      );
    }
    rows.sort((a, b) => b.amount.compareTo(a.amount));
    return rows;
  }

  Future<void> _showJamaList({
    required String title,
    required List<_JamaListRow> rows,
  }) async {
    final list = List<_JamaListRow>.of(rows);
    final total = list.fold(0.0, (a, r) => a + r.amount);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => _JamaListPage(
          title: title,
          rows: list,
          totalLabel: _money(total),
          onPrint: list.isEmpty
              ? null
              : () => _printJamaList(title: title, rows: list),
        ),
      ),
    );
  }

  Future<void> _printJamaList({
    required String title,
    required List<_JamaListRow> rows,
  }) async {
    var club = 'Lions Club';
    try {
      final profile = await ClubSettingsStore.load();
      final n = profile.clubName.trim();
      if (n.isNotEmpty) club = n;
    } catch (_) {}
    if (!mounted) return;

    // Pehle in-app preview — file error pe bhi print view dikhe.
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => _JamaPrintPreviewPage(
          club: club,
          title: title,
          rows: rows,
          onOpenExternal: () => _openJamaHtmlInBrowser(
            club: club,
            title: title,
            rows: rows,
          ),
        ),
      ),
    );
  }

  Future<void> _openJamaHtmlInBrowser({
    required String club,
    required String title,
    required List<_JamaListRow> rows,
  }) async {
    final total = rows.fold(0.0, (a, r) => a + r.amount);
    String esc(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');

    final buf = StringBuffer()
      ..writeln('<!DOCTYPE html><html><head><meta charset="utf-8">')
      ..writeln('<title>${esc(title)}</title>')
      ..writeln('<style>')
      ..writeln(
        'body{font-family:Helvetica,Arial,sans-serif;margin:24px;color:#111}',
      )
      ..writeln('h1{font-size:18px;margin:0 0 4px}')
      ..writeln(
        'h2{font-size:14px;margin:0 0 12px;color:#444;font-weight:600}',
      )
      ..writeln(
        'table{width:100%;border-collapse:collapse;font-size:12px}',
      )
      ..writeln(
        'th,td{border:1px solid #ccc;padding:6px 8px;text-align:left}',
      )
      ..writeln('th{background:#f3eef8}')
      ..writeln('td.amt,th.amt{text-align:right}')
      ..writeln('.foot{margin-top:12px;font-weight:700}')
      ..writeln('</style></head><body>')
      ..writeln('<h1>${esc(club)}</h1>')
      ..writeln(
        '<h2>${esc(title)} — ${rows.length} log · ₹${total.round()}</h2>',
      )
      ..writeln(
        '<table><thead><tr><th>#</th><th>Name</th><th>Date</th><th>Mode</th><th>Detail</th><th class="amt">Amount</th></tr></thead><tbody>',
      );
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      buf.writeln(
        '<tr><td>${i + 1}</td><td>${esc(r.name)}</td><td>${esc(r.date)}</td><td>${esc(r.method)}</td><td>${esc(r.detail)}</td><td class="amt">₹${r.amount.round()}</td></tr>',
      );
    }
    buf
      ..writeln('</tbody></table>')
      ..writeln('<p class="foot">Kul: ₹${total.round()}</p>')
      ..writeln('<script>window.onload=function(){window.print();}</script>')
      ..writeln('</body></html>');

    // Sandbox cache kabhi missing hota hai — docs folder + create recursive.
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/jama_print');
    await dir.create(recursive: true);
    final safe = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final file = File(
      '${dir.path}/jama_${safe.isEmpty ? "list" : safe}_${DateTime.now().millisecondsSinceEpoch}.html',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(buf.toString(), flush: true);
    if (!await file.exists()) {
      throw StateError('HTML file save nahi hui');
    }

    var opened = false;
    if (!kIsWeb && Platform.isMacOS) {
      final r = await Process.run('open', [file.absolute.path]);
      opened = r.exitCode == 0;
    } else if (!kIsWeb && Platform.isLinux) {
      final r = await Process.run('xdg-open', [file.absolute.path]);
      opened = r.exitCode == 0;
    } else if (!kIsWeb && Platform.isWindows) {
      final r =
          await Process.run('cmd', ['/c', 'start', '', file.absolute.path]);
      opened = r.exitCode == 0;
    }
    if (!opened) {
      opened = await launchUrl(
        Uri.file(file.absolute.path),
        mode: LaunchMode.externalApplication,
      );
    }
    if (!opened) {
      throw StateError('Browser open nahi hua: ${file.path}');
    }
  }

  Future<void> _saveFeeSettings() async {
    var couple = double.tryParse(
          _coupleFeeCtrl.text.replaceAll(RegExp(r'[^\d.]'), ''),
        ) ??
        0;
    var single = double.tryParse(
          _singleFeeCtrl.text.replaceAll(RegExp(r'[^\d.]'), ''),
        ) ??
        0;
    final board = double.tryParse(
          _boardFeeCtrl.text.replaceAll(RegExp(r'[^\d.]'), ''),
        ) ??
        0;
    if (couple <= 0) couple = 5000;
    if (single <= 0) single = 3000;
    final old = AccountsStore.settings;
    await AccountsStore.saveSettings(
      AccountsFeeSettings(
        coupleFee: couple,
        singleFee: single,
        boardFee: board,
      ),
    );
    // Unpaid rows jo purani fixed pe the — nayi fixed pe update
    for (final unit in _units) {
      final f = AccountsStore.feeForMember(unit.primary.id);
      if (f == null || f.paid) continue;
      final oldAmt = unit.defaultAmount(old);
      final wasDefault = f.amount == oldAmt || f.amount <= 0;
      if (!wasDefault) continue;
      await AccountsStore.upsertFee(
        f.copyWith(amount: unit.defaultAmount(AccountsStore.settings)),
      );
    }
    if (!mounted) return;
    await _reload();
    if (!mounted) return;
    setState(() => _feesEditing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fixed fees save · list update')),
    );
  }

  void _startEditFees() {
    setState(() => _feesEditing = true);
  }

  void _cancelEditFees() {
    setState(() {
      _feesEditing = false;
      _coupleFeeCtrl.text =
          (_settings.coupleFee > 0 ? _settings.coupleFee : 5000)
              .round()
              .toString();
      _singleFeeCtrl.text =
          (_settings.singleFee > 0 ? _settings.singleFee : 3000)
              .round()
              .toString();
      _boardFeeCtrl.text = _settings.boardFee.round().toString();
    });
  }

  Future<void> _editFee(_FeeUnit unit) async {
    final existing = AccountsStore.feeForMember(unit.primary.id);
    final fixed = unit.membershipAmount(_settings);
    var amount = _membershipFromRecord(unit, existing);
    if (amount <= 0) amount = fixed;
    var method = existing?.method ?? PaymentMethod.cash;
    final membershipAlreadyJama = existing?.paid ?? false;
    final boardAlreadyJama = existing?.boardPaid ?? false;
    /// membership | board fee | Donation | Other | custom chip
    var receiveKind = 'Membership fees';
    double? donationChip;
    var localCustomKinds = List<String>.of(AccountsStore.customReceiveKinds);
    final detail = TextEditingController(text: existing?.paymentDetail ?? '');
    final date = TextEditingController(
      text: (existing?.date.trim().isNotEmpty == true)
          ? existing!.date
          : _today(),
    );
    final otherNameCtrl = TextEditingController();
    final showBoardToggle = unit.isBoard && _settings.boardFee > 0;
    final boardDueAmt = showBoardToggle ? _settings.boardFee : 0.0;
    final kulDena = fixed + boardDueAmt;
    final feeJama = (membershipAlreadyJama ? amount : 0.0) +
        (boardAlreadyJama ? boardDueAmt : 0.0);
    final donJama = _donationsForUnit(unit);
    final kulJama = feeJama + donJama;
    // Pehle se jama options list se hatao.
    final receiveOptions = <String>[
      if (!membershipAlreadyJama) 'Membership fees',
      if (showBoardToggle && !boardAlreadyJama) boardMemberBoardFeeKind,
      ...memberReceiveCategories,
    ];
    if (membershipAlreadyJama) {
      receiveKind = showBoardToggle && !boardAlreadyJama
          ? boardMemberBoardFeeKind
          : 'Donation';
    }
    final amountCtrl = TextEditingController(
      text: receiveKind == 'Membership fees'
          ? (amount > 0 ? amount.round().toString() : '')
          : receiveKind == boardMemberBoardFeeKind
              ? boardDueAmt.round().toString()
              : '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final isMembership = receiveKind == 'Membership fees';
          final isBoardFee = receiveKind == boardMemberBoardFeeKind;
          final isOther = receiveKind == 'Other';
          final isDonation = receiveKind == 'Donation';
          final isCustomKind = !receiveOptions.contains(receiveKind);
          final otherPreview = otherNameCtrl.text.trim();
          final dropdownValue =
              receiveOptions.contains(receiveKind) ? receiveKind : null;
          return AlertDialog(
            title: Text(
              existing != null ? 'Edit · ${unit.title}' : unit.title,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    unit.subtitle,
                    style:
                        TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  if (unit.isBoard) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Board: ${unit.boardTitles.join(', ')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: AppTheme.purple,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EEF8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Kul dena\n${_money(kulDena)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Jama\n${_money(kulJama)}',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  height: 1.25,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          membershipAlreadyJama
                              ? 'MF · ${_money(amount)} · jama'
                              : 'MF · ${_money(amount)} · baki',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: membershipAlreadyJama
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                        if (showBoardToggle) ...[
                          const SizedBox(height: 2),
                          Text(
                            boardAlreadyJama
                                ? 'BF · ${_money(boardDueAmt)} · jama'
                                : 'BF · ${_money(boardDueAmt)} · baki',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: boardAlreadyJama
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ],
                        for (final e in _donationLinesForUnit(unit)) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${e.key} · ${_money(e.value)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: date,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (localCustomKinds.isNotEmpty ||
                      (isOther && otherPreview.isNotEmpty)) ...[
                    Text(
                      'Other boxes',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in localCustomKinds)
                          ChoiceChip(
                            label: Text(c),
                            selected: receiveKind == c,
                            onSelected: (_) => setLocal(() {
                              receiveKind = c;
                              otherNameCtrl.clear();
                              amountCtrl.clear();
                              donationChip = null;
                            }),
                          ),
                        if (isOther &&
                            otherPreview.isNotEmpty &&
                            !localCustomKinds.any(
                              (e) =>
                                  e.toLowerCase() ==
                                  otherPreview.toLowerCase(),
                            ))
                          Chip(
                            avatar: const Icon(Icons.add, size: 16),
                            label: Text(otherPreview),
                            backgroundColor: const Color(0xFFE8F5E9),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Paisa kis liye',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: dropdownValue,
                        hint: Text(
                          isCustomKind ? receiveKind : 'Select',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        isExpanded: true,
                        isDense: true,
                        items: [
                          for (final k in receiveOptions)
                            DropdownMenuItem(
                              value: k,
                              child: Text(
                                k == 'Membership fees'
                                    ? 'MF'
                                    : k == boardMemberBoardFeeKind
                                        ? 'BF'
                                        : k,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() {
                            receiveKind = v;
                            if (v == 'Membership fees') {
                              final a = _membershipFromRecord(unit, existing);
                              amountCtrl.text =
                                  (a > 0 ? a : fixed).round().toString();
                              donationChip = null;
                              otherNameCtrl.clear();
                            } else if (v == boardMemberBoardFeeKind) {
                              amountCtrl.text =
                                  boardDueAmt.round().toString();
                              donationChip = null;
                              otherNameCtrl.clear();
                            } else {
                              amountCtrl.clear();
                              donationChip = null;
                              if (v != 'Other') otherNameCtrl.clear();
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  if (isOther) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: otherNameCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setLocal(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Other ka naam *',
                        hintText: 'Jaise Melvin Jones / LCIF / …',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFFFF8E7),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (!isMembership &&
                      !isBoardFee &&
                      isDonation) ...[
                    Text(
                      'Amount select',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final a in donationAmountChoices)
                          ChoiceChip(
                            label: Text('₹${a.round()}'),
                            selected: donationChip == a,
                            onSelected: (_) => setLocal(() {
                              donationChip = a;
                              amountCtrl.text = a.round().toString();
                            }),
                          ),
                        ChoiceChip(
                          label: const Text('Custom'),
                          selected: donationChip == null,
                          onSelected: (_) => setLocal(() {
                            donationChip = null;
                            amountCtrl.clear();
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (_) {
                      if (!isMembership && !isBoardFee) {
                        setLocal(() => donationChip = null);
                      }
                    },
                    readOnly: isBoardFee,
                    decoration: InputDecoration(
                      labelText: isMembership
                          ? 'MF (₹)'
                          : isBoardFee
                              ? 'BF (₹)'
                              : isOther
                                  ? 'Amount (₹)'
                                  : '$receiveKind (₹)',
                      helperText: isMembership
                          ? unit.amountBreakdown(_settings)
                          : isBoardFee
                              ? 'Board member fixed board fee'
                              : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Jama kis tarah se',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<PaymentMethod>(
                        value: method,
                        isExpanded: true,
                        isDense: true,
                        items: [
                          for (final m in PaymentMethod.values)
                            DropdownMenuItem(value: m, child: Text(m.label)),
                        ],
                        onChanged: (v) {
                          if (v != null) setLocal(() => method = v);
                        },
                      ),
                    ),
                  ),
                  if (method == PaymentMethod.cheque) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: detail,
                      decoration: const InputDecoration(
                        labelText: 'Cheque detail *',
                        hintText: 'Cheque no / bank / date',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFF7F5FB),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    final amt = double.tryParse(
          amountCtrl.text.replaceAll(RegExp(r'[^\d.]'), ''),
        ) ??
        0;
    final detailText =
        method == PaymentMethod.cheque ? detail.text.trim() : '';
    final dateText = date.text.trim();
    final kind = receiveKind;
    final otherName = otherNameCtrl.text.trim();
    detail.dispose();
    date.dispose();
    amountCtrl.dispose();
    otherNameCtrl.dispose();
    if (ok != true) return;
    if (method == PaymentMethod.cheque && detailText.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cheque detail zaroori hai')),
      );
      return;
    }

    if (kind == boardMemberBoardFeeKind) {
      if (boardAlreadyJama) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('BF pehle se jama hai')),
        );
        return;
      }
      if (!showBoardToggle) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Is member pe BF nahi')),
        );
        return;
      }
      final memAmt = _membershipFromRecord(unit, existing);
      await AccountsStore.upsertFee(
        MemberFeeRecord(
          id: existing?.id ?? AccountsStore.newFeeId(),
          memberId: unit.primary.id,
          spouseMemberId: unit.spouse?.id ?? '',
          amount: memAmt > 0 ? memAmt : fixed,
          isCouple: unit.isCouple,
          paid: existing?.paid ?? false,
          boardPaid: true,
          method: method,
          paymentDetail: detailText,
          date: dateText,
          note: existing?.note ?? '',
        ),
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('BF jama · ₹${boardDueAmt.round()}'),
        ),
      );
      return;
    }

    if (kind != 'Membership fees') {
      if (amt <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$kind amount zaroori hai')),
        );
        return;
      }
      var category = kind;
      if (kind == 'Other') {
        if (otherName.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Other ka naam likho')),
          );
          return;
        }
        category = otherName;
      }
      await AccountsStore.upsertDonation(
        MemberDonation(
          id: AccountsStore.newDonationId(),
          memberId: unit.primary.id,
          amount: amt,
          category: category,
          method: method,
          paymentDetail: detailText,
          date: dateText,
          note: '',
        ),
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$category save · ₹${amt.round()}')),
      );
      return;
    }

    // Save = membership jama mark (toggle nahi).
    if (membershipAlreadyJama) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MF pehle se jama hai')),
      );
      return;
    }
    await AccountsStore.upsertFee(
      MemberFeeRecord(
        id: existing?.id ?? AccountsStore.newFeeId(),
        memberId: unit.primary.id,
        spouseMemberId: unit.spouse?.id ?? '',
        amount: amt > 0 ? amt : fixed,
        isCouple: unit.isCouple,
        paid: true,
        boardPaid: existing?.boardPaid ?? false,
        method: method,
        paymentDetail: detailText,
        date: dateText,
        note: existing?.note ?? '',
      ),
    );
    await _reload();
  }

  Future<void> _addDonation() => _upsertDonation();

  Future<void> _upsertDonation([MemberDonation? existing]) async {
    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pehle Members list load karein')),
      );
      return;
    }
    final editing = existing != null;
    Member? member = editing ? _memberOf(existing.memberId) : null;
    if (editing && member == null && existing.memberId.isNotEmpty) {
      member = MemberStore.byId(existing.memberId);
    }
    final existingCat = (existing?.category.trim().isEmpty ?? true)
        ? 'Donation'
        : existing!.category.trim();
    final isKnownFixed = memberReceiveCategories.contains(existingCat);
    final isKnownCustom =
        AccountsStore.customReceiveKinds.any(
          (e) => e.toLowerCase() == existingCat.toLowerCase(),
        ) ||
        (!isKnownFixed && existingCat.toLowerCase() != 'donation');
    var category = existing == null
        ? 'Donation'
        : (isKnownFixed
            ? existingCat
            : (isKnownCustom ? existingCat : 'Other'));
    double? amount;
    if (existing != null) {
      final a = existing.amount;
      if (donationAmountChoices.any((c) => (c - a).abs() < 0.5)) {
        amount = donationAmountChoices.firstWhere((c) => (c - a).abs() < 0.5);
      }
    }
    var localCustomKinds = List<String>.of(AccountsStore.customReceiveKinds);
    var method = existing?.method ?? PaymentMethod.cash;
    final detail = TextEditingController(
      text: existing?.paymentDetail ?? '',
    );
    final customAmt = TextEditingController(
      text: existing != null && amount == null
          ? existing.amount.round().toString()
          : '',
    );
    final otherNameCtrl = TextEditingController(
      text: category == 'Other' ? existingCat : '',
    );
    final date = TextEditingController(
      text: (existing?.date.trim().isNotEmpty == true)
          ? existing!.date
          : _today(),
    );
    final typeOptions = <String>[...memberReceiveCategories];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final isOther = category == 'Other';
          final isDonation = category == 'Donation';
          final isCustom = !typeOptions.contains(category);
          final otherPreview = otherNameCtrl.text.trim();
          final dropdownValue =
              typeOptions.contains(category) ? category : null;
          return AlertDialog(
            title: Text(
              editing
                  ? 'Edit — Donation / Other'
                  : 'Received — Donation / Other',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: date,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (localCustomKinds.isNotEmpty ||
                      (isOther && otherPreview.isNotEmpty)) ...[
                    Text(
                      'Other boxes',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in localCustomKinds)
                          ChoiceChip(
                            label: Text(c),
                            selected: category == c,
                            onSelected: (_) => setLocal(() {
                              category = c;
                              otherNameCtrl.clear();
                            }),
                          ),
                        if (isOther &&
                            otherPreview.isNotEmpty &&
                            !localCustomKinds.any(
                              (e) =>
                                  e.toLowerCase() ==
                                  otherPreview.toLowerCase(),
                            ))
                          Chip(
                            avatar: const Icon(Icons.add, size: 16),
                            label: Text(otherPreview),
                            backgroundColor: const Color(0xFFE8F5E9),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: dropdownValue,
                        hint: Text(
                          isCustom ? category : 'Select',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        isExpanded: true,
                        isDense: true,
                        items: [
                          for (final c in typeOptions)
                            DropdownMenuItem(value: c, child: Text(c)),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() {
                            category = v;
                            if (v != 'Other') otherNameCtrl.clear();
                          });
                        },
                      ),
                    ),
                  ),
                  if (isOther) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: otherNameCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setLocal(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Other ka naam *',
                        hintText: 'Jaise Melvin Jones / LCIF / …',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFFFF8E7),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      member?.displayName ?? 'Member select karein',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${isCustom || isOther ? (otherPreview.isNotEmpty ? otherPreview : category) : category} kis member ne di',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final picked = await pickClubMember(
                        context: ctx,
                        members: _members,
                        currentId: member?.id ?? '',
                        title: 'Member',
                        allowClear: false,
                      );
                      if (picked != null && picked.id.isNotEmpty) {
                        setLocal(() => member = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  if (isDonation) ...[
                    Text(
                      'Amount select',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final a in donationAmountChoices)
                          ChoiceChip(
                            label: Text('₹${a.round()}'),
                            selected: amount == a,
                            onSelected: (_) => setLocal(() {
                              amount = a;
                              customAmt.clear();
                            }),
                          ),
                        ChoiceChip(
                          label: const Text('Custom'),
                          selected:
                              amount == null && customAmt.text.isNotEmpty,
                          onSelected: (_) => setLocal(() => amount = null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: customAmt,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (_) => setLocal(() => amount = null),
                    decoration: InputDecoration(
                      labelText: isDonation
                          ? 'Custom amount (₹)'
                          : 'Amount (₹)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Jama kis tarah se',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<PaymentMethod>(
                        value: method,
                        isExpanded: true,
                        isDense: true,
                        items: [
                          for (final m in PaymentMethod.values)
                            DropdownMenuItem(value: m, child: Text(m.label)),
                        ],
                        onChanged: (v) {
                          if (v != null) setLocal(() => method = v);
                        },
                      ),
                    ),
                  ),
                  if (method == PaymentMethod.cheque) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: detail,
                      decoration: const InputDecoration(
                        labelText: 'Cheque detail *',
                        hintText: 'Cheque no / bank / date',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFF7F5FB),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    final resolvedAmt = amount ??
        double.tryParse(customAmt.text.replaceAll(RegExp(r'[^\d.]'), '')) ??
        0;
    final mid = member?.id ?? '';
    var cat = category;
    if (category == 'Other') {
      cat = otherNameCtrl.text.trim();
    }
    final detailText =
        method == PaymentMethod.cheque ? detail.text.trim() : '';
    final dateText = date.text.trim();
    detail.dispose();
    customAmt.dispose();
    otherNameCtrl.dispose();
    date.dispose();
    if (ok != true) return;
    if (mid.isEmpty || resolvedAmt <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member aur amount zaroori hain')),
      );
      return;
    }
    if (cat.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Other ka naam likho')),
      );
      return;
    }
    if (method == PaymentMethod.cheque && detailText.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cheque detail zaroori hai')),
      );
      return;
    }
    await AccountsStore.upsertDonation(
      MemberDonation(
        id: existing?.id ?? AccountsStore.newDonationId(),
        memberId: mid,
        amount: resolvedAmt,
        category: cat,
        method: method,
        paymentDetail: detailText,
        date: dateText,
        note: existing?.note ?? '',
      ),
    );
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          editing
              ? '$cat update · ₹${resolvedAmt.round()}'
              : '$cat save · ₹${resolvedAmt.round()}',
        ),
      ),
    );
  }

  Future<void> _addLedger({LedgerType type = LedgerType.income}) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final category = TextEditingController(
      text: type == LedgerType.income ? 'Other income' : 'Program expense',
    );
    final date = TextEditingController(text: _today());
    var selected = type;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Ledger entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<LedgerType>(
                  segments: const [
                    ButtonSegment(
                      value: LedgerType.income,
                      label: Text('Jama'),
                    ),
                    ButtonSegment(
                      value: LedgerType.expense,
                      label: Text('Kharch'),
                    ),
                  ],
                  selected: {selected},
                  onSelectionChanged: (s) => setLocal(() => selected = s.first),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: date,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final amt = double.tryParse(amount.text.trim()) ?? 0;
    final dateText = date.text.trim();
    final catText = category.text.trim();
    final noteText = note.text.trim();
    amount.dispose();
    note.dispose();
    category.dispose();
    date.dispose();
    if (ok != true || amt <= 0) return;
    await AccountsStore.upsert(
      LedgerEntry(
        id: AccountsStore.newId(),
        type: selected,
        amount: amt,
        date: dateText,
        category: catText,
        note: noteText,
      ),
    );
    await _reload();
  }

  Member? _memberOf(String id) => MemberStore.byId(id);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!widget.embedded) ...[
          Text(
            widget.canEdit ? 'Received money' : 'Accounts',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
          ),
          if (!widget.canEdit) ...[
            const SizedBox(height: 4),
            Text(
              'Sirf dekhne ke liye — fee / donation Treasurer Work se badlege',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 10),
        ],
        Card(
          color: const Color(0xFFFFF0F3),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: const Color(0xFFF5C6D0).withValues(alpha: 0.8)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Fixed fees',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    if (widget.canEdit && !_feesEditing)
                      SizedBox(
                        height: 28,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: const Color(0xFFC45C7A),
                          ),
                          onPressed: _startEditFees,
                          child: const Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      )
                    else if (widget.canEdit && _feesEditing) ...[
                      SizedBox(
                        height: 28,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _cancelEditFees,
                          child: const Text('Cancel', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 2),
                      SizedBox(
                        height: 28,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: const Color(0xFFC45C7A),
                          ),
                          onPressed: _saveFeeSettings,
                          child: const Text(
                            'Save',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _miniFeeField(
                        controller: _coupleFeeCtrl,
                        label: 'Couple',
                        enabled: widget.canEdit && _feesEditing,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _miniFeeField(
                        controller: _singleFeeCtrl,
                        label: 'Single M.',
                        enabled: widget.canEdit && _feesEditing,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _miniFeeField(
                        controller: _boardFeeCtrl,
                        label: 'Board',
                        enabled: widget.canEdit && _feesEditing,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 1–3 Club fees
                Row(
                  children: [
                    Expanded(
                      child: _sumCard(
                        'Total Fee Club',
                        _feesExpected,
                        AppTheme.purple,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _sumCard(
                        'Kul Jama Club',
                        _feesJama,
                        Colors.green.shade700,
                        onTap: () => _showJamaList(
                          title: 'Kul Jama Club',
                          rows: _kulJamaClubRows(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _sumCard(
                        'Baki',
                        _feesBaki,
                        Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // 4–6 Board fees
                Row(
                  children: [
                    Expanded(
                      child: _sumCard(
                        'Total Board Fee',
                        _boardExpected,
                        AppTheme.purple,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _sumCard(
                        'Board Kul Jama',
                        _boardJama,
                        Colors.green.shade700,
                        onTap: () => _showJamaList(
                          title: 'Board Kul Jama',
                          rows: _boardKulJamaRows(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _sumCard(
                        'Baki',
                        _boardBaki,
                        Colors.deepOrange.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Donation + Other kinds — sirf amount; Club Balance mein add.
                ..._receiveAmountBoxRows(),
                const SizedBox(height: 6),
                // 7–8 Kharch
                Row(
                  children: [
                    Expanded(
                      child: _sumCard(
                        'Kul Kharch Club',
                        _clubKharch,
                        Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _sumCard(
                        'Kul Kharch Board',
                        _boardKharch,
                        Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // 9–10 Balance (alag) — Club Balance = fees jama + donation/other − kharch
                Row(
                  children: [
                    Expanded(
                      child: _sumCard(
                        'Club Balance',
                        _clubBalance,
                        AppTheme.purple,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _sumCard(
                        'Board Balance',
                        _boardBalance,
                        const Color(0xFF5B4B8A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: _pendingFilterChip(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _sectionTitle('Members — fees list')),
            if (_pendingCount > 0)
              Text(
                'Baki: $_pendingCount',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: Colors.orange.shade800,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.canEdit
              ? 'Tap / edit icon → fee · donation edit'
              : 'Sirf show — change Treasurer Work se',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        if (_units.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Members nahi mile — pehle Members module mein list load karein.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          )
        else if (_visibleUnits.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _showPendingOnly
                    ? 'Koi baki fees nahi — sab jama ho chuki.'
                    : 'List empty.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          )
        else
          ..._visibleUnits.map(_feeRow),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _sectionTitle('Donation / Other'),
            ),
            if (widget.canEdit)
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _addDonation,
                icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
                label: const Text('Add'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_donations.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.volunteer_activism_outlined),
              title: const Text('Abhi koi entry nahi'),
              subtitle: Text(
                widget.canEdit
                    ? 'Add ya member tap → Donation / Other'
                    : 'Treasurer Work se add hota hai',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
              ),
            ),
          )
        else
          ..._donations.map((d) {
            final m = _memberOf(d.memberId);
            final cat = d.category.trim().isEmpty ? 'Donation' : d.category;
            return Card(
              child: ListTile(
                onTap: widget.canEdit ? () => _upsertDonation(d) : null,
                leading: const Icon(Icons.volunteer_activism, color: AppTheme.purple),
                title: Text(
                  '$cat · ${m?.displayName ?? 'Member'} · ${_money(d.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  [
                    d.date,
                    d.method.label,
                    if (d.paymentDetail.isNotEmpty) d.paymentDetail,
                    if (d.note.isNotEmpty) d.note,
                    if (widget.canEdit) 'tap → edit',
                  ].where((e) => e.trim().isNotEmpty).join(' · '),
                ),
                trailing: widget.canEdit
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _upsertDonation(d),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final del = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete entry?'),
                                  content: Text('$cat · ${_money(d.amount)}'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (del == true) {
                                await AccountsStore.deleteDonation(d.id);
                                await _reload();
                              }
                            },
                          ),
                        ],
                      )
                    : null,
              ),
            );
          }),
        if (widget.showLedger) ...[
          const SizedBox(height: 18),
          Card(
            color: const Color(0xFFF7F5FB),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionTitle('Jama / Kharch (ledger)'),
                  if (widget.canEdit) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _addLedger(type: LedgerType.income),
                          icon: const Icon(Icons.add),
                          label: const Text('Jama'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              _addLedger(type: LedgerType.expense),
                          icon: const Icon(Icons.remove),
                          label: const Text('Kharch'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (_entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Anya ledger entries yahan box mein.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    )
                  else
                    ..._entries.map(
                      (e) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: e.type == LedgerType.income
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.red.withValues(alpha: 0.12),
                            child: Icon(
                              e.type == LedgerType.income
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: e.type == LedgerType.income
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                          title: Text(
                            '${_money(e.amount)} · ${e.category.isEmpty ? e.type.name : e.category}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [e.date, if (e.note.isNotEmpty) e.note].join(' · '),
                          ),
                          trailing: widget.canEdit
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    await AccountsStore.delete(e.id);
                                    await _reload();
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );

    if (widget.embedded) {
      return Material(color: Colors.transparent, child: body);
    }
    if (ModalRoute.of(context)?.isFirst == false) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accounts')),
        body: body,
      );
    }
    return Material(color: Colors.transparent, child: body);
  }

  Widget _feeRow(_FeeUnit unit) {
    final rec = AccountsStore.feeForMember(unit.primary.id);
    final memAmt = _membershipFromRecord(unit, rec);
    final boardDue =
        unit.isBoard && _settings.boardFee > 0 ? _settings.boardFee : 0.0;
    final kulDena = memAmt + boardDue;
    final paid = rec?.paid == true;
    final boardPaid = rec?.boardPaid == true;
    final memJama = paid ? memAmt : 0.0;
    final boardJama = boardPaid ? boardDue : 0.0;
    final feeJama = memJama + boardJama;
    final donJama = _donationsForUnit(unit);
    final kulJama = feeJama + donJama;
    // Baki sirf fee pe — donation fee baki kam nahi karta.
    final baki = (kulDena - feeJama).clamp(0.0, double.infinity);
    final allClear = !_unitPending(unit, rec);

    return Card(
      child: InkWell(
        onTap: widget.canEdit
            ? () => _editFee(unit)
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Fee jama Treasurer Work → Received money se',
                    ),
                  ),
                );
              },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: allClear
                        ? Colors.green.withValues(alpha: 0.15)
                        : AppTheme.purple.withValues(alpha: 0.12),
                    child: Icon(
                      unit.isBoard
                          ? Icons.badge_outlined
                          : (unit.isCouple
                              ? Icons.favorite
                              : Icons.person_outline),
                      color:
                          allClear ? Colors.green.shade700 : AppTheme.purple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.primary.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        if (unit.spouse != null)
                          Text(
                            'Patni: ${unit.spouse!.displayName}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade800,
                              fontSize: 13.5,
                            ),
                          )
                        else if (unit.isCouple)
                          Text(
                            'Patni: link nahi — Members mein spouse set karein',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 12.5,
                            ),
                          ),
                        Text(
                          unit.subtitle,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                        if (unit.isBoard)
                          Text(
                            'Board: ${unit.boardTitles.join(', ')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppTheme.purple,
                            ),
                          ),
                        Text(
                          unit.amountBreakdown(_settings),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          paid ? 'MF: jama' : 'MF: baki',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: paid
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                          ),
                        ),
                        if (boardDue > 0)
                          Text(
                            boardPaid ? 'BF: jama' : 'BF: baki',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: boardPaid
                                  ? Colors.green.shade700
                                  : Colors.orange.shade800,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Kul dena',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        _money(kulDena),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: allClear
                              ? Colors.green.shade700
                              : AppTheme.purple,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Jama',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        _money(kulJama),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Colors.green.shade700,
                        ),
                      ),
                      for (final e in _donationLinesForUnit(unit)) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${e.key} ${_money(e.value)}',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ],
                      if (baki > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Baki ${_money(baki)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                      if (widget.canEdit) ...[
                        const SizedBox(height: 4),
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Text(
      t,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: AppTheme.ink,
      ),
    );
  }

  Widget _miniFeeField({
    required TextEditingController controller,
    required String label,
    bool enabled = false,
  }) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        enabled: enabled,
        readOnly: !enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: enabled ? AppTheme.ink : Colors.grey.shade800,
        ),
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFFC45C7A),
          ),
          prefixText: '₹ ',
          prefixStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
          filled: true,
          fillColor: enabled ? Colors.white : const Color(0xFFFFF8FA),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFF5C6D0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFF5C6D0)),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: const Color(0xFFF5C6D0).withValues(alpha: 0.7),
            ),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Color(0xFFC45C7A), width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _pendingFilterChip() {
    return Material(
      color: _showPendingOnly
          ? const Color(0xFFC45C7A)
          : Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => setState(() => _showPendingOnly = !_showPendingOnly),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFF5C6D0).withValues(alpha: 0.9),
            ),
          ),
          child: Text(
            _showPendingOnly
                ? 'Baki fees ON · $_pendingCount'
                : 'Baki fees list · $_pendingCount',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: _showPendingOnly ? Colors.white : Colors.orange.shade800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sumCard(
    String label,
    double value,
    Color color, {
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: onTap != null
            ? Colors.white
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: onTap != null
              ? AppTheme.purple.withValues(alpha: 0.35)
              : const Color(0xFFF5C6D0).withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _money(value),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: color,
            ),
          ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'List / Print',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.purple.withValues(alpha: 0.85),
                ),
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: card,
      ),
    );
  }
}
