import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/club_role.dart';
import '../../models/member.dart';
import '../../services/member_excel_import.dart';
import '../../services/member_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/member_photo.dart';
import 'member_form_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key, required this.role});

  final ClubRole role;

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _search = TextEditingController();
  List<Member> _all = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  /// Anyone who can open Members can add/edit/delete/import.
  bool get _canEdit => widget.role.modules.contains(AppModule.members);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final list = await MemberStore.load();
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Member> get _filtered {
    final q = _search.text;
    final list = _all.where((m) => m.matchesQuery(q)).toList()
      ..sort(
        (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    return list;
  }

  Future<void> _openForm({Member? existing}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MemberFormScreen(existing: existing)),
    );
    if (changed == true && mounted) await _reload();
  }

  Future<void> _delete(Member m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete member?'),
        content: Text('${m.displayName} delete ho jayega.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await MemberStore.delete(m.id);
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${m.displayName} deleted')),
    );
  }

  Future<void> _importExcel() async {
    if (_busy) return;
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          ...MemberExcelService.allowedExtensions,
          'numbers',
        ],
        withData: true,
      );
      if (!mounted) return;
      if (picked == null || picked.files.isEmpty) return;

      setState(() => _busy = true);
      final file = picked.files.first;
      var bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File read nahi ho payi')),
        );
        return;
      }

      final name = file.name;
      final (result, members) = MemberExcelService.parseFile(
        bytes: bytes,
        fileName: name,
      );
      if (!mounted) return;
      if (result.errors.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Import'),
            content: Text(result.errors.first),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      if (members.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File mein koi valid member nahi mila')),
        );
        return;
      }

      final mode = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Excel / Numbers import'),
          content: Text(
            '${members.length} members mile ($name).\n\n'
            'Merge = pehle se matching update + naye add\n'
            'Replace all = purani list hata kar ye list',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, 'merge'), child: const Text('Merge')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'replace'),
              child: const Text('Replace all'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (mode == 'merge') {
        final added = await MemberStore.mergeImported(members);
        await _reload();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import done · ${members.length} rows · $added new')),
        );
      } else if (mode == 'replace') {
        await MemberStore.replaceAll(members);
        await _reload();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('List replaced · ${members.length} members')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveTemplate() async {
    if (_busy) return;
    final kind = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Template save'),
        content: const Text(
          'Excel (.xlsx) ya CSV (Numbers ke liye) — kaunsa chahiye?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'csv'),
            child: const Text('CSV (Numbers)'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'xlsx'),
            child: const Text('Excel'),
          ),
        ],
      ),
    );
    if (kind == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final bytes = kind == 'csv'
          ? MemberExcelService.buildCsvTemplateBytes()
          : MemberExcelService.buildTemplateBytes();
      Directory? dir;
      try {
        dir = await getDownloadsDirectory();
      } catch (_) {}
      dir ??= await getApplicationDocumentsDirectory();
      final path = kind == 'csv'
          ? '${dir.path}/lions_members_template.csv'
          : '${dir.path}/lions_members_template.xlsx';
      await File(path).writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template saved:\n$path')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Load error: $_error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _reload, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final list = _filtered;

    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Members (${_all.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                ),
                const SizedBox(height: 8),
                if (_canEdit)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _openForm(),
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text('Add Member'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _importExcel,
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Load Excel / Numbers'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _saveTemplate,
                        icon: const Icon(Icons.table_view_outlined, size: 18),
                        label: const Text('Template'),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search name, phone, profession…',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
                if (_busy) const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? _EmptyState(
                    hasMembers: _all.isNotEmpty,
                    canEdit: _canEdit,
                    onAdd: () => _openForm(),
                    onExcel: _importExcel,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final m = list[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            leading: MemberFaceAvatar(member: m, radius: 22),
                            title: Text(
                              m.displayName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              [
                                m.gender.label,
                                m.membershipType.label,
                                if (m.primaryPhone.isNotEmpty) m.primaryPhone,
                                if (m.address.trim().isNotEmpty) m.address.trim(),
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _showDetails(m),
                            trailing: _canEdit
                                ? PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') _openForm(existing: m);
                                      if (v == 'delete') _delete(m);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                                    ],
                                  )
                                : const Icon(Icons.chevron_right),
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

  void _showDetails(Member m) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    m.displayName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${m.gender.label} · ${m.membershipType.label} Member',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  Center(child: MemberFaceAvatar(member: m, radius: 40)),
                  const SizedBox(height: 12),
                  _detailBlock('Person', [
                    'Name: ${m.name.isEmpty ? '—' : m.name}',
                    'Phone: ${m.phone.isEmpty ? '—' : m.phone}',
                    'DOB: ${m.dob.isEmpty ? '—' : m.dob}',
                    'Profession: ${m.profession.isEmpty ? '—' : m.profession}',
                    'Photo: ${m.photo.trim().isEmpty ? '—' : 'Saved'}',
                    'Anniversary: ${m.anniversary.isEmpty ? '—' : m.anniversary}',
                    'Address: ${m.address.isEmpty ? '—' : m.address}',
                    'Proposer: ${m.proposer.isEmpty ? '—' : m.proposer}',
                    _spouseDetailLine(m),
                  ]),
                  if (_canEdit) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openForm(existing: m);
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _delete(m);
                            },
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            label: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _spouseDetailLine(Member m) {
    final spouseName = MemberStore.spouseDisplayName(m);
    if (spouseName != null) return 'Spouse: $spouseName';
    if (m.membershipType == MembershipType.couple) {
      return 'Spouse: — (Edit se pati/patni link karein)';
    }
    return 'Spouse: —';
  }

  Widget _detailBlock(String title, List<String> lines) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.purple),
            ),
            const SizedBox(height: 6),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(line),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasMembers,
    required this.canEdit,
    required this.onAdd,
    required this.onExcel,
  });

  final bool hasMembers;
  final bool canEdit;
  final VoidCallback onAdd;
  final VoidCallback onExcel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              hasMembers ? 'Search se koi match nahi mila' : 'Abhi koi member save nahi hai',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasMembers
                  ? 'Search clear karke list dekhein'
                  : 'Add Member dabayein ya Excel / Numbers (CSV) se load karein',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (canEdit && !hasMembers) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add Member'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onExcel,
                icon: const Icon(Icons.upload_file),
                label: const Text('Excel / Numbers se load'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
