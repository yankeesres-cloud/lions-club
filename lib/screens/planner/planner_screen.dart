import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/club_role.dart';
import '../../models/member.dart';
import '../../models/planned_program.dart';
import '../../services/board_store.dart';
import '../../services/member_store.dart';
import '../../services/planner_excel_import.dart';
import '../../services/planner_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/member_photo.dart';
import '../../widgets/member_picker.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, required this.role});

  final ClubRole role;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  List<PlannedProgram> _all = [];
  List<Member> _members = [];
  bool _loading = true;
  bool _busy = false;
  bool _showPast = false;

  /// 0 = sab months
  int _filterMonth = 0;
  int _filterYear = DateTime.now().year;
  String? _filterProgramId;

  bool get _canEdit => true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final programs = await PlannerStore.load();
    final members = await MemberStore.ensureLoaded();
    await BoardStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _all = programs;
      _members = members;
      _loading = false;
      if (_filterProgramId != null &&
          !_all.any((p) => p.id == _filterProgramId)) {
        _filterProgramId = null;
      }
    });
  }

  List<PlannedProgram> get _baseList {
    var list = _showPast ? _all : _all.where((p) => p.isUpcoming).toList();
    if (_filterMonth >= 1 && _filterMonth <= 12) {
      list = list
          .where(
            (p) =>
                p.resolvedMonth == _filterMonth &&
                p.resolvedYear == _filterYear,
          )
          .toList();
    }
    return list;
  }

  List<PlannedProgram> get _visible {
    final list = _baseList;
    if (_filterProgramId == null || _filterProgramId!.isEmpty) return list;
    return list.where((p) => p.id == _filterProgramId).toList();
  }

  List<PlannedProgram> get _reminders =>
      _all.where((p) => p.isInReminderWindow).toList();

  Member? _memberOf(String id) {
    if (id.trim().isEmpty) return null;
    try {
      return _members.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openForm({PlannedProgram? existing}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProgramFormScreen(
          existing: existing,
          members: _members,
          defaultMonth: _filterMonth,
          defaultYear: _filterYear,
        ),
      ),
    );
    if (changed == true) await _reload();
  }

  Future<void> _openWork(PlannedProgram p) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProgramWorkScreen(programId: p.id),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _delete(PlannedProgram p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete program?'),
        content: Text('"${p.title}" planner se hat jayega.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await PlannerStore.delete(p.id);
    await _reload();
  }

  Future<void> _importExcel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final pick = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: PlannerExcelImport.allowedExtensions,
        withData: true,
      );
      if (pick == null || pick.files.isEmpty) return;
      final f = pick.files.first;
      final bytes = f.bytes ??
          (f.path != null ? await File(f.path!).readAsBytes() : null);
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File read nahi hui')),
        );
        return;
      }
      final (result, programs) = await PlannerExcelImport.parseFile(
        fileName: f.name,
        bytes: bytes,
        members: _members,
      );
      if (!mounted) return;
      if (programs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errors.isEmpty
                  ? 'Koi program nahi mila'
                  : result.errors.join('\n'),
            ),
          ),
        );
        return;
      }
      final mode = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Planner'),
          content: Text(
            '${programs.length} programs mile (${f.name}).\n'
            'PC 1–4 + Director VP select (1/2/3) — Board se auto.\n'
            'Mac Numbers: Export → CSV/Excel karke load karein.\n\n'
            'Merge = update + naye\nReplace = purani list hatao',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, 'merge'), child: const Text('Merge')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'replace'),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (mode == 'merge') {
        final added = await PlannerStore.mergeImported(programs);
        await _reload();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import · ${programs.length} · $added new')),
        );
      } else if (mode == 'replace') {
        await PlannerStore.replaceAll(programs);
        await _reload();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Planner replaced · ${programs.length}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import fail: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveTemplate() async {
    try {
      final bytes = PlannerExcelImport.buildCsvTemplateBytes();
      final path = await FilePicker.saveFile(
        dialogTitle: 'Planner CSV template',
        fileName: 'lions_planner_template.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: bytes,
      );
      if (!mounted) return;
      if (path == null) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/lions_planner_template.csv');
        await file.writeAsBytes(bytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template: ${file.path}')),
        );
        return;
      }
      final file = File(path);
      if (!await file.exists()) await file.writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template fail: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final list = _visible;
    final monthPrograms = _baseList;
    final reminders = _reminders;
    final years = {
      DateTime.now().year,
      DateTime.now().year + 1,
      for (final p in _all) p.resolvedYear,
    }.where((y) => y >= 2000).toList()
      ..sort();

    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Planner (${list.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Month → Program · PC (1–4) · Director VP (1/2/3)',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                if (reminders.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Card(
                    color: AppTheme.goldSoft.withValues(alpha: 0.35),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reminder (10 din pehle)',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          for (final r in reminders.take(5))
                            Text(
                              '• ${r.title} — ${r.dateTimeLabel}',
                              style: const TextStyle(fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('y$_filterYear'),
                        initialValue: years.contains(_filterYear)
                            ? _filterYear
                            : years.first,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          border: OutlineInputBorder(),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: [
                          for (final y in years)
                            DropdownMenuItem(value: y, child: Text('$y')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _filterYear = v;
                            _filterProgramId = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('m$_filterMonth'),
                        initialValue: _filterMonth,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Month select',
                          border: OutlineInputBorder(),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: [
                          const DropdownMenuItem(value: 0, child: Text('Sabhi months')),
                          for (var i = 1; i <= 12; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(PlannedProgram.monthLabels[i - 1]),
                            ),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _filterMonth = v ?? 0;
                            _filterProgramId = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey('p${_filterProgramId ?? 'all'}_${monthPrograms.length}'),
                  initialValue: _filterProgramId ?? '__ALL__',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Program select',
                    border: OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.event_note),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '__ALL__',
                      child: Text('Sabhi programs (${monthPrograms.length})'),
                    ),
                    for (final p in monthPrograms)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          '${p.title} · ${p.dateTimeLabel}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _filterProgramId =
                          (v == null || v == '__ALL__') ? null : v;
                    });
                  },
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_canEdit) ...[
                      FilledButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _importExcel,
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Excel load'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saveTemplate,
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('CSV template'),
                      ),
                    ],
                    FilterChip(
                      label: Text(_showPast ? 'Past bhee' : 'Upcoming'),
                      selected: _showPast,
                      onSelected: (v) => setState(() => _showPast = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      'Is filter mein program nahi.\nExcel load ya Add karein.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = list[i];
                      final pcs = p.pcsNormalized
                          .map(_memberOf)
                          .whereType<Member>()
                          .toList();
                      // Board VP se live naam (saved id empty ho to bhi)
                      final directorId = () {
                        final fromBoard = p.directorVpLevel >= 1
                            ? BoardStore.memberIdForVpLevel(p.directorVpLevel)
                            : '';
                        if (fromBoard.isNotEmpty) return fromBoard;
                        return p.directorMemberId;
                      }();
                      final director = _memberOf(directorId);
                      final remind = p.isInReminderWindow;
                      return Card(
                        color: remind
                            ? AppTheme.goldSoft.withValues(alpha: 0.22)
                            : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                p.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Month: ${p.monthYearLabel}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.purple,
                                ),
                              ),
                              Text('Anumanit date: ${p.dateTimeLabel}'),
                              Text('Anumanit budget: ${p.budgetLabel}'),
                              if (p.place.trim().isNotEmpty)
                                Text('Place: ${p.place.trim()}'),
                              Text(
                                'PC (${pcs.length}): ${pcs.isEmpty ? '—' : pcs.map((m) => m.displayName).join(', ')}',
                              ),
                              Text(
                                p.directorVpLevel < 1
                                    ? 'Director: —'
                                    : director == null
                                        ? 'Director: VP-${p.directorVpLevel} (Board pe assign nahi)'
                                        : 'Director: VP-${p.directorVpLevel} · ${director.displayName}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: () => _openWork(p),
                                    icon: const Icon(Icons.checklist, size: 18),
                                    label: const Text('Work'),
                                  ),
                                  if (_canEdit) ...[
                                    OutlinedButton.icon(
                                      onPressed: () => _openForm(existing: p),
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text('Edit'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _delete(p),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      label: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ProgramWorkScreen extends StatefulWidget {
  const ProgramWorkScreen({super.key, required this.programId});

  final String programId;

  @override
  State<ProgramWorkScreen> createState() => _ProgramWorkScreenState();
}

class _ProgramWorkScreenState extends State<ProgramWorkScreen> {
  PlannedProgram? _program;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await PlannerStore.ensureLoaded();
    PlannedProgram? found;
    try {
      found = PlannerStore.current.firstWhere((p) => p.id == widget.programId);
    } catch (_) {
      found = null;
    }
    if (found != null && found.checklist.isEmpty) {
      found = found.copyWith(checklist: PlannedProgram.defaultChecklist());
      await PlannerStore.upsert(found);
    }
    if (!mounted) return;
    setState(() {
      _program = found;
      _loading = false;
    });
  }

  Future<void> _toggle(ProgramChecklistItem item) async {
    final p = _program;
    if (p == null) return;
    final next = p.checklist
        .map((c) => c.id == item.id ? c.copyWith(done: !c.done) : c)
        .toList();
    await PlannerStore.updateChecklist(p.id, next);
    if (!mounted) return;
    setState(() => _program = p.copyWith(checklist: next));
  }

  Future<void> _addItem() async {
    final ctrl = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Checklist item'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Kaam / task',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (title == null || title.isEmpty || _program == null) return;
    final item = ProgramChecklistItem(
      id: 'chk_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
    );
    final next = [..._program!.checklist, item];
    await PlannerStore.updateChecklist(_program!.id, next);
    if (!mounted) return;
    setState(() => _program = _program!.copyWith(checklist: next));
  }

  Future<void> _editAttendance() async {
    final p = _program;
    if (p == null) return;
    await MemberStore.ensureLoaded();
    if (!mounted) return;
    final selected = await pickClubMembers(
      context: context,
      members: MemberStore.current,
      selectedIds: p.attendanceNormalized,
      title: 'Program haziri (attendance)',
      maxSelection: 200,
    );
    if (!mounted || selected == null) return;
    final next = p.copyWith(attendedMemberIds: selected);
    await PlannerStore.upsert(next);
    if (!mounted) return;
    setState(() => _program = next);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = _program;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Work')),
        body: const Center(child: Text('Program nahi mila')),
      );
    }
    final done = p.checklistDoneCount;
    final total = p.checklistTotal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Program Work'),
        actions: [
          IconButton(onPressed: _addItem, icon: const Icon(Icons.add_task)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(p.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text('${p.monthYearLabel} · ${p.dateTimeLabel} · Budget ${p.budgetLabel}'),
          const SizedBox(height: 12),
          Text('Checklist ($done/$total)', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: total == 0 ? 0 : done / total,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          for (final item in p.checklist)
            Card(
              child: CheckboxListTile(
                value: item.done,
                onChanged: (_) => _toggle(item),
                title: Text(
                  item.title,
                  style: TextStyle(
                    decoration: item.done ? TextDecoration.lineThrough : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppTheme.purple,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Haziri / Attendance (${p.attendanceNormalized.length})',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Jo member program mein aaye — unki star rating badhegi',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _editAttendance,
            icon: const Icon(Icons.how_to_reg_outlined),
            label: Text(
              p.attendanceNormalized.isEmpty
                  ? 'Haziri mark karein'
                  : '${p.attendanceNormalized.length} members — badlein',
            ),
          ),
          if (p.attendanceNormalized.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final id in p.attendanceNormalized.take(12))
                  Chip(
                    label: Text(
                      MemberStore.byId(id)?.displayName ?? 'Member',
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                if (p.attendanceNormalized.length > 12)
                  Chip(
                    label: Text('+${p.attendanceNormalized.length - 12}'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 72),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
    );
  }
}

class ProgramFormScreen extends StatefulWidget {
  const ProgramFormScreen({
    super.key,
    this.existing,
    required this.members,
    this.defaultMonth = 0,
    this.defaultYear = 0,
  });

  final PlannedProgram? existing;
  final List<Member> members;
  final int defaultMonth;
  final int defaultYear;

  @override
  State<ProgramFormScreen> createState() => _ProgramFormScreenState();
}

class _ProgramFormScreenState extends State<ProgramFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _date;
  late final TextEditingController _time;
  late final TextEditingController _place;
  late final TextEditingController _notes;
  late final TextEditingController _budget;
  late String _id;
  late int _planMonth;
  late int _planYear;
  List<String> _pcIds = [];
  int _directorVp = 1;
  List<ProgramChecklistItem> _checklist = [];
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  /// Board pe jo VP assigned hai — wahi director.
  String get _directorId => BoardStore.memberIdForVpLevel(_directorVp);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    _id = e?.id ?? PlannerStore.newId();
    _title = TextEditingController(text: e?.title ?? '');
    _date = TextEditingController(text: e?.expectedDate ?? '');
    _time = TextEditingController(text: e?.expectedTime ?? '');
    _place = TextEditingController(text: e?.place ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _budget = TextEditingController(
      text: (e != null && e.estimatedBudget > 0)
          ? e.estimatedBudget.round().toString()
          : '',
    );
    _pcIds = List.of(e?.pcsNormalized ?? const []);
    _directorVp = (e?.directorVpLevel ?? 0).clamp(0, 3);
    if (_directorVp < 1) _directorVp = 1;
    _planMonth = e?.resolvedMonth ??
        (widget.defaultMonth >= 1 ? widget.defaultMonth : now.month);
    _planYear = e?.resolvedYear ??
        (widget.defaultYear >= 2000 ? widget.defaultYear : now.year);
    if (_planMonth < 1) _planMonth = now.month;
    _checklist = e?.checklist.isNotEmpty == true
        ? List.of(e!.checklist)
        : PlannedProgram.defaultChecklist();
    BoardStore.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _date.dispose();
    _time.dispose();
    _place.dispose();
    _notes.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final parsed = Member.parseFlexibleDate(_date.text);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed ?? DateTime(_planYear, _planMonth.clamp(1, 12), 15),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _date.text = Member.formatDate(picked);
      _planMonth = picked.month;
      _planYear = picked.year;
    });
  }

  Future<void> _pickTime() async {
    final parts = _time.text.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 10,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      _time.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _pickPcs() async {
    final selected = await pickClubMembers(
      context: context,
      members: widget.members,
      selectedIds: _pcIds,
      title: 'Program PC select (1–4)',
      maxSelection: PlannedProgram.maxPcs,
    );
    if (!mounted || selected == null) return;
    setState(() => _pcIds = selected);
  }

  Member? _m(String id) {
    if (id.isEmpty) return null;
    try {
      return widget.members.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Program name zaroori hai')),
      );
      return;
    }
    setState(() => _saving = true);
    final budget = double.tryParse(
          _budget.text.replaceAll(RegExp(r'[^\d.]'), ''),
        ) ??
        0;
    await PlannerStore.upsert(
      PlannedProgram(
        id: _id,
        title: _title.text.trim(),
        expectedDate: _date.text.trim(),
        expectedTime: _time.text.trim(),
        place: _place.text.trim(),
        notes: _notes.text.trim(),
        pcMemberIds: _pcIds,
        directorMemberId: _directorId,
        directorVpLevel: _directorVp,
        planMonth: _planMonth,
        planYear: _planYear,
        estimatedBudget: budget,
        checklist: _checklist,
        attendedMemberIds: widget.existing?.attendedMemberIds ?? const [],
      ),
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Program' : 'Add Program'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Month-wise · Anumanit date/budget · PC (1–4) · Director (VP-1/2/3)',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey(_planMonth),
              initialValue: _planMonth.clamp(1, 12),
              decoration: const InputDecoration(
                labelText: 'Month',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: [
                for (var i = 1; i <= 12; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(PlannedProgram.monthLabels[i - 1]),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _planMonth = v);
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Program name *',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.event_note),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _date,
              readOnly: true,
              onTap: _pickDate,
              decoration: InputDecoration(
                labelText: 'Anumanit date',
                hintText: 'dd/MM/yyyy',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _date.clear()),
                  icon: const Icon(Icons.clear, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _time,
              readOnly: true,
              onTap: _pickTime,
              decoration: InputDecoration(
                labelText: 'Anumanit time',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.access_time),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _time.clear()),
                  icon: const Icon(Icons.clear, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _budget,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Anumanit budget (₹)',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _place,
              decoration: const InputDecoration(
                labelText: 'Place / Venue',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.purple.withValues(alpha: 0.12),
                  child: Text(
                    '${_pcIds.length}',
                    style: const TextStyle(
                      color: AppTheme.purple,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  _pcIds.isEmpty
                      ? 'PC select karein (1–4)'
                      : _pcIds
                          .map(_m)
                          .whereType<Member>()
                          .map((m) => m.displayName)
                          .join(', '),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Program PC — 1, 2, 3 ya 4 members'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickPcs,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              key: ValueKey('vp$_directorVp'),
              initialValue: _directorVp.clamp(1, 3),
              decoration: const InputDecoration(
                labelText: 'Director (VP) — 1 / 2 / 3',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: [
                for (final level in [1, 2, 3])
                  DropdownMenuItem(
                    value: level,
                    child: Text(
                      BoardStore.vpSeatLabel(
                        level,
                        nameOf: (id) => _m(id)?.displayName ?? '',
                      ),
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _directorVp = v);
              },
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final director = _m(_directorId);
                return Card(
                  color: AppTheme.purple.withValues(alpha: 0.06),
                  child: ListTile(
                    leading: director != null
                        ? MemberFaceAvatar(member: director, radius: 22)
                        : CircleAvatar(
                            backgroundColor:
                                AppTheme.purple.withValues(alpha: 0.12),
                            child: Text(
                              '$_directorVp',
                              style: const TextStyle(
                                color: AppTheme.purple,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                    title: Text(
                      director?.displayName ??
                          'VP-$_directorVp — Board pe naam assign nahi',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      director == null
                          ? 'Board Members → V.P.-$_directorVp pe member select karein'
                          : 'Program Director · Board V.P.-$_directorVp',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_isEdit ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
