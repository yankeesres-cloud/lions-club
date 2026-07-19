import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../services/accounts_store.dart';
import '../../theme/app_theme.dart';
import 'accounts_screen.dart';

/// Treasurer desk — Received money (fee/donation) + Expenses.
class TreasurerWorkScreen extends StatefulWidget {
  const TreasurerWorkScreen({super.key});

  @override
  State<TreasurerWorkScreen> createState() => _TreasurerWorkScreenState();
}

class _TreasurerWorkScreenState extends State<TreasurerWorkScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Treasurer Work',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Fee / donation yahan · Accounts mein sirf show',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            labelColor: AppTheme.purple,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: AppTheme.purple,
            tabs: const [
              Tab(
                icon: Icon(Icons.south_west, size: 18),
                text: 'Received money',
              ),
              Tab(
                icon: Icon(Icons.north_east, size: 18),
                text: 'Expenses',
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              // Swipe band — boxes par click clear rahe.
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                AccountsScreen(
                  embedded: true,
                  canEdit: true,
                  showLedger: false,
                ),
                _TreasurerExpensesPane(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TreasurerExpensesPane extends StatefulWidget {
  const _TreasurerExpensesPane();

  @override
  State<_TreasurerExpensesPane> createState() => _TreasurerExpensesPaneState();
}

class _TreasurerExpensesPaneState extends State<_TreasurerExpensesPane> {
  bool _loading = true;
  List<ExpenseProgram> _programs = [];
  List<LedgerEntry> _otherExpenses = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    await AccountsStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _programs = AccountsStore.expensePrograms;
      _otherExpenses = AccountsStore.current
          .where(
            (e) =>
                e.type == LedgerType.expense && e.programId.trim().isEmpty,
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      _loading = false;
    });
  }

  String _today() => DateFormat('dd/MM/yyyy').format(DateTime.now());

  DateTime? _parseDate(String raw) {
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(raw.trim());
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickDate(
    TextEditingController ctrl, [
    VoidCallback? onPicked,
  ]) async {
    final now = DateTime.now();
    final initial = _parseDate(ctrl.text) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    ctrl.text = DateFormat('dd/MM/yyyy').format(picked);
    onPicked?.call();
  }

  Future<void> _addProgram() async {
    final nameCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: _today());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add Program'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Program name *',
                    hintText: 'Jaise Eye Camp / Installation',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dateCtrl,
                  readOnly: true,
                  onTap: () => _pickDate(dateCtrl, () => setLocal(() {})),
                  decoration: InputDecoration(
                    labelText: 'Program date *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: () =>
                          _pickDate(dateCtrl, () => setLocal(() {})),
                    ),
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

    final name = nameCtrl.text.trim();
    final date = dateCtrl.text.trim();
    nameCtrl.dispose();
    dateCtrl.dispose();
    if (ok != true) return;
    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Program name zaroori hai')),
      );
      return;
    }
    if (date.isEmpty || _parseDate(date) == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Program date choose karein')),
      );
      return;
    }

    final prog = ExpenseProgram(
      id: AccountsStore.newExpenseProgramId(),
      name: name,
      date: date,
    );
    await AccountsStore.upsertExpenseProgram(prog);
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Program save · $name')),
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ExpenseProgramPage(programId: prog.id),
      ),
    );
    await _reload();
  }

  Future<void> _openProgram(ExpenseProgram p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ExpenseProgramPage(programId: p.id),
      ),
    );
    await _reload();
  }

  Future<void> _addOtherExpense() => _upsertOtherExpense();

  Future<void> _upsertOtherExpense([LedgerEntry? existing]) async {
    final editing = existing != null;
    final amount = TextEditingController(
      text: existing != null && existing.amount > 0
          ? existing.amount.round().toString()
          : '',
    );
    final category = TextEditingController(
      text: existing?.category.trim().isNotEmpty == true
          ? existing!.category
          : 'Club expense',
    );
    final note = TextEditingController(text: existing?.note ?? '');
    final date = TextEditingController(
      text: (existing?.date.trim().isNotEmpty == true)
          ? existing!.date
          : _today(),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(editing ? 'Edit expense' : 'Other / club expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: date,
                  readOnly: true,
                  onTap: () => _pickDate(date, () => setLocal(() {})),
                  decoration: InputDecoration(
                    labelText: 'Date',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: () =>
                          _pickDate(date, () => setLocal(() {})),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amount,
                  autofocus: true,
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
    final cat = category.text.trim();
    final d = date.text.trim();
    final n = note.text.trim();
    amount.dispose();
    category.dispose();
    note.dispose();
    date.dispose();
    if (ok != true || amt <= 0) return;

    await AccountsStore.upsert(
      LedgerEntry(
        id: existing?.id ?? AccountsStore.newId(),
        type: LedgerType.expense,
        amount: amt,
        date: d.isEmpty ? _today() : d,
        category: cat.isEmpty ? 'Club expense' : cat,
        note: n,
      ),
    );
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          editing
              ? 'Expense update · ₹${amt.round()}'
              : 'Expense save · ₹${amt.round()}',
        ),
      ),
    );
  }

  double get _totalKharch => AccountsStore.totalExpense;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFFF3EEF8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppTheme.purple,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kul Kharch',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '₹${_totalKharch.round()}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _addProgram,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('1. Add Program'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pehle program name + date · phir andar expenses',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _addOtherExpense,
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Other / club expense'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AccountsScreen(canEdit: false),
              ),
            );
          },
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Accounts summary (sirf dekhna)'),
        ),
        const SizedBox(height: 16),
        Text(
          'Programs (${_programs.length})',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (_programs.isEmpty)
          Text(
            'Abhi koi program nahi — upar se Add Program karein',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          for (final p in _programs)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.purple.withValues(alpha: 0.12),
                  child: const Icon(Icons.event, color: AppTheme.purple),
                ),
                title: Text(
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Program date: ${p.date} · '
                  '${AccountsStore.expensesForProgram(p.id).length} expense · '
                  '₹${AccountsStore.programExpenseTotal(p.id).round()}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openProgram(p),
              ),
            ),
        if (_otherExpenses.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Other / club expenses (${_otherExpenses.length})',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final e in _otherExpenses.take(30))
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade50,
                  child: Icon(Icons.south_west, color: Colors.red.shade700),
                ),
                title: Text(
                  e.category.trim().isEmpty ? 'Expense' : e.category.trim(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    e.date,
                    if (e.note.trim().isNotEmpty) e.note.trim(),
                  ].join(' · '),
                ),
                trailing: Text(
                  '₹${e.amount.round()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.red,
                  ),
                ),
                onTap: () => _upsertOtherExpense(e),
                onLongPress: () async {
                  final del = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete expense?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (del == true) {
                    await AccountsStore.delete(e.id);
                    await _reload();
                  }
                },
              ),
            ),
        ],
      ],
    );
  }
}

/// Program ke andar expenses add / edit.
class _ExpenseProgramPage extends StatefulWidget {
  const _ExpenseProgramPage({required this.programId});

  final String programId;

  @override
  State<_ExpenseProgramPage> createState() => _ExpenseProgramPageState();
}

class _ExpenseProgramPageState extends State<_ExpenseProgramPage> {
  ExpenseProgram? _program;
  List<LedgerEntry> _expenses = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    await AccountsStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _program = AccountsStore.expenseProgramById(widget.programId);
      _expenses = AccountsStore.expensesForProgram(widget.programId);
    });
  }

  String _today() => DateFormat('dd/MM/yyyy').format(DateTime.now());

  DateTime? _parseDate(String raw) {
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(raw.trim());
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickDate(
    TextEditingController ctrl, [
    VoidCallback? onPicked,
  ]) async {
    final now = DateTime.now();
    final initial = _parseDate(ctrl.text) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    ctrl.text = DateFormat('dd/MM/yyyy').format(picked);
    onPicked?.call();
  }

  Future<void> _addOrEditExpense([LedgerEntry? existing]) async {
    final prog = _program;
    if (prog == null) return;
    final editing = existing != null;
    final amount = TextEditingController(
      text: existing != null && existing.amount > 0
          ? existing.amount.round().toString()
          : '',
    );
    final note = TextEditingController(text: existing?.note ?? '');
    final date = TextEditingController(
      text: (existing?.date.trim().isNotEmpty == true)
          ? existing!.date
          : _today(),
    );
    final detail = TextEditingController(
      text: existing?.category.trim().isNotEmpty == true &&
              existing!.category != 'Program · ${prog.name}'
          ? existing.category
          : '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(editing ? 'Edit expense' : 'Add expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${prog.name} · ${prog.date}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: date,
                  readOnly: true,
                  onTap: () => _pickDate(date, () => setLocal(() {})),
                  decoration: InputDecoration(
                    labelText: 'Expense date *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: () =>
                          _pickDate(date, () => setLocal(() {})),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amount,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Kharch amount (₹) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detail,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Kis liye (optional)',
                    hintText: 'Jaise Tent / Food / Banner',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(
                    labelText: 'Note / bill detail',
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
    final d = date.text.trim();
    final n = note.text.trim();
    final det = detail.text.trim();
    amount.dispose();
    note.dispose();
    date.dispose();
    detail.dispose();
    if (ok != true || amt <= 0) return;

    await AccountsStore.upsert(
      LedgerEntry(
        id: existing?.id ?? AccountsStore.newId(),
        type: LedgerType.expense,
        amount: amt,
        date: d.isEmpty ? _today() : d,
        category: det.isEmpty ? 'Program · ${prog.name}' : det,
        note: n,
        programId: prog.id,
      ),
    );
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Expense save · ₹${amt.round()}')),
    );
  }

  Future<void> _deleteProgram() async {
    final prog = _program;
    if (prog == null) return;
    final del = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Program delete?'),
        content: Text(
          '"${prog.name}" aur uske ${_expenses.length} expense delete ho jayenge.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (del != true) return;
    await AccountsStore.deleteExpenseProgram(prog.id);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final prog = _program;
    if (prog == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Program')),
        body: const Center(child: Text('Program nahi mila')),
      );
    }

    final total = _expenses.fold(0.0, (a, e) => a + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text(prog.name),
        actions: [
          IconButton(
            tooltip: 'Delete program',
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteProgram,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditExpense(),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          Card(
            color: const Color(0xFFF3EEF8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prog.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Program date: ${prog.date}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kul kharch · ₹${total.round()}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Expenses (${_expenses.length})',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (_expenses.isEmpty)
            Text(
              'Abhi koi expense nahi — neeche Add expense dabao',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            for (final e in _expenses)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade50,
                    child: Icon(Icons.south_west, color: Colors.red.shade700),
                  ),
                  title: Text(
                    e.category.trim().isEmpty ? 'Expense' : e.category.trim(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      e.date,
                      if (e.note.trim().isNotEmpty) e.note.trim(),
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹${e.amount.round()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.red,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _addOrEditExpense(e),
                      ),
                    ],
                  ),
                  onTap: () => _addOrEditExpense(e),
                  onLongPress: () async {
                    final del = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete expense?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (del == true) {
                      await AccountsStore.delete(e.id);
                      await _reload();
                    }
                  },
                ),
              ),
        ],
      ),
    );
  }
}
