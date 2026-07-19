import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/accounts_store.dart';
import '../../theme/app_theme.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  bool _loading = true;
  List<LedgerEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await AccountsStore.load();
    if (!mounted) return;
    setState(() {
      _entries = list;
      _loading = false;
    });
  }

  Future<void> _add({LedgerType type = LedgerType.income}) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final category = TextEditingController(
      text: type == LedgerType.income ? 'Membership / Fee' : 'Program expense',
    );
    final date = TextEditingController(
      text:
          '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
    );
    var selected = type;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Accounts entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<LedgerType>(
                  segments: const [
                    ButtonSegment(value: LedgerType.income, label: Text('Jama')),
                    ButtonSegment(value: LedgerType.expense, label: Text('Kharch')),
                  ],
                  selected: {selected},
                  onSelectionChanged: (s) => setLocal(() => selected = s.first),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final amt = double.tryParse(amount.text.trim()) ?? 0;
    if (amt <= 0) return;
    await AccountsStore.upsert(
      LedgerEntry(
        id: AccountsStore.newId(),
        type: selected,
        amount: amt,
        date: date.text.trim(),
        category: category.text.trim(),
        note: note.text.trim(),
      ),
    );
    await _reload();
  }

  Future<void> _delete(LedgerEntry e) async {
    await AccountsStore.delete(e.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final income = AccountsStore.totalIncome;
    final expense = AccountsStore.totalExpense;
    final balance = AccountsStore.balance;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          Text(
            'Treasurer — Accounts',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Jama, kharch aur balance — Treasurer desk',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(child: _sumCard('Jama', income, Colors.green.shade700)),
            const SizedBox(width: 8),
            Expanded(child: _sumCard('Kharch', expense, Colors.red.shade700)),
            const SizedBox(width: 8),
            Expanded(child: _sumCard('Balance', balance, AppTheme.purple)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _add(type: LedgerType.income),
              icon: const Icon(Icons.add),
              label: const Text('Jama'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _add(type: LedgerType.expense),
              icon: const Icon(Icons.remove),
              label: const Text('Kharch'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_entries.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Abhi koi entry nahi. Jama / Kharch add karein.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
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
                  '₹${e.amount.toStringAsFixed(0)} · ${e.category.isEmpty ? e.type.name : e.category}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    e.date,
                    if (e.note.isNotEmpty) e.note,
                  ].join(' · '),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(e),
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.embedded) return body;
    final scroll = ListView(
      padding: const EdgeInsets.all(16),
      children: [body],
    );
    // Standalone route (from desk) needs Scaffold; shell embeds without AppBar.
    if (ModalRoute.of(context)?.isFirst == false) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accounts')),
        body: scroll,
      );
    }
    return Material(color: Colors.transparent, child: scroll);
  }

  Widget _sumCard(String label, double value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Text(
              '₹${value.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
