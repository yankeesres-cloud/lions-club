import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/club_contact.dart';
import '../../models/club_role.dart';
import '../../services/club_contact_import.dart';
import '../../services/club_contact_store.dart';
import '../../theme/app_theme.dart';

class ClubDirectoryScreen extends StatefulWidget {
  const ClubDirectoryScreen({super.key, required this.role});

  final ClubRole role;

  @override
  State<ClubDirectoryScreen> createState() => _ClubDirectoryScreenState();
}

class _ClubDirectoryScreenState extends State<ClubDirectoryScreen> {
  final _search = TextEditingController();
  List<ClubContact> _all = [];
  List<String> _clubs = [];
  /// null / '' = sab clubs
  String? _selectedClub;
  bool _loading = true;
  bool _busy = false;

  static const _allClubs = '__ALL__';

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
    await ClubContactStore.purgeGarbage();
    final list = await ClubContactStore.load();
    final clubs = ClubContactStore.clubNames;
    if (!mounted) return;
    setState(() {
      _all = list;
      _clubs = clubs;
      // Keep selection if club still exists
      if (_selectedClub != null &&
          _selectedClub!.isNotEmpty &&
          !_clubs.contains(_selectedClub)) {
        _selectedClub = null;
      }
      _loading = false;
    });
  }

  List<ClubContact> get _filtered {
    Iterable<ClubContact> list = _all;
    final club = _selectedClub?.trim() ?? '';
    if (club.isNotEmpty) {
      list = list.where(
        (c) => c.clubName.trim().toLowerCase() == club.toLowerCase(),
      );
    }
    final q = _search.text;
    return list.where((c) => c.matchesQuery(q)).toList();
  }

  Future<void> _addOrEdit([ClubContact? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final club = TextEditingController(
      text: existing?.clubName ?? (_selectedClub ?? ''),
    );
    final post = TextEditingController(text: existing?.designation ?? '');
    final district = TextEditingController(text: existing?.district ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Contact add' : 'Contact edit'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_clubs.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: club.text.trim().isNotEmpty &&
                            _clubs.contains(club.text.trim())
                        ? club.text.trim()
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Club select / type',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                    items: [
                      for (final n in _clubs)
                        DropdownMenuItem(value: n, child: Text(n, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) {
                      if (v != null) club.text = v;
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: club,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Club ka naam',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.apartment_outlined),
                    hintText: 'Naya club type karein',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: post,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Post / Designation',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile no.',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '10 digit',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: district,
                  decoration: const InputDecoration(
                    labelText: 'District (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final c = ClubContact(
      id: existing?.id ?? ClubContactStore.newId(),
      name: name.text.trim(),
      phone: phone.text.trim(),
      clubName: club.text.trim(),
      designation: post.text.trim(),
      district: district.text.trim(),
      notes: notes.text.trim(),
    );
    if (!c.isSane) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sahi Name likhein (garbage/PDF junk nahi)')),
      );
      return;
    }
    await ClubContactStore.upsert(c);
    await _reload();
  }

  Future<void> _call(ClubContact c) async {
    if (!c.hasPhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mobile number nahi hai')),
      );
      return;
    }
    final uri = Uri.parse(c.telUri);
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Call open nahi hua: ${c.phoneDisplay}')),
      );
    }
  }

  Future<void> _copyPhone(ClubContact c) async {
    if (!c.hasPhone) return;
    await Clipboard.setData(ClipboardData(text: c.phoneDigits));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copy: ${c.phoneDisplay}')),
    );
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final pick = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ClubContactImport.allowedExtensions,
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
      final (result, contacts) = await ClubContactImport.parseFile(
        fileName: f.name,
        bytes: bytes,
      );
      if (!mounted) return;
      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errors.isEmpty
                  ? 'Koi saaf contact nahi mila — CSV template use karein'
                  : result.errors.join('\n'),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
      final mode = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import contacts'),
          content: Text(
            '${contacts.length} contacts mile (${f.name})\n'
            '${result.skipped > 0 ? 'Skipped: ${result.skipped}\n' : ''}\n'
            'Merge = naye + update\n'
            'Replace = purani list hata kar ye',
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
        final added = await ClubContactStore.mergeImported(contacts);
        await _reload();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import · ${contacts.length} · $added new')),
        );
      } else if (mode == 'replace') {
        await ClubContactStore.replaceAll(contacts);
        await _reload();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('List replaced · ${contacts.length}')),
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
      final bytes = ClubContactImport.buildCsvTemplateBytes();
      final path = await FilePicker.saveFile(
        dialogTitle: 'CSV template save',
        fileName: 'lions_anya_club_members_template.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: bytes,
      );
      if (!mounted) return;
      if (path == null) {
        // Fallback: app Documents
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/lions_anya_club_members_template.csv');
        await file.writeAsBytes(bytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template save: ${file.path}')),
        );
        return;
      }
      // Some platforms write via bytes already; ensure file exists.
      final file = File(path);
      if (!await file.exists()) {
        await file.writeAsBytes(bytes);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template save: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template download fail: $e')),
      );
    }
  }

  Future<void> _clearGarbage() async {
    final before = _all.length;
    await ClubContactStore.purgeGarbage();
    await _reload();
    if (!mounted) return;
    final removed = before - _all.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed > 0
              ? '$removed galat/PDF junk entries hataayi'
              : 'List saaf — ab sirf readable contacts',
        ),
      ),
    );
  }

  Future<void> _delete(ClubContact c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete contact?'),
        content: Text(c.displayName),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
    if (ok != true) return;
    await ClubContactStore.delete(c.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final list = _filtered;

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
                  'Anya Club / Guest List (${list.length}${_selectedClub == null ? ' / ${_all.length}' : ''})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Club select → uske members → Call / Copy',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedClub ?? _allClubs),
                  initialValue: _selectedClub ?? _allClubs,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Club select karein',
                    prefixIcon: Icon(Icons.apartment_outlined),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: _allClubs,
                      child: Text('Sabhi clubs (${_clubs.length})'),
                    ),
                    for (final club in _clubs)
                      DropdownMenuItem(
                        value: club,
                        child: Text(
                          '$club (${_all.where((c) => c.clubName.trim().toLowerCase() == club.toLowerCase()).length})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _selectedClub = (v == null || v == _allClubs) ? null : v;
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Is club mein search: name / post / phone…',
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
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _addOrEdit(),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Add'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _import,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Excel / CSV load'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saveTemplate,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('CSV template'),
                    ),
                    TextButton.icon(
                      onPressed: _clearGarbage,
                      icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                      label: const Text('Junk hatao'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _all.isEmpty
                            ? 'List khali hai.\nExcel columns: CLUB | NAME | POST | PHONE\n(Club pehle column — template download karein.)'
                            : _selectedClub != null
                                ? 'Is club mein koi member nahi / search match nahi'
                                : 'Search se koi match nahi',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ContactCard(
                      contact: list[i],
                      onEdit: () => _addOrEdit(list[i]),
                      onDelete: () => _delete(list[i]),
                      onCall: () => _call(list[i]),
                      onCopy: () => _copyPhone(list[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
    required this.onCall,
    required this.onCopy,
  });

  final ClubContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCall;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final c = contact;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _line('Club', c.clubName.trim().isEmpty ? '—' : c.clubName.trim(),
                emphasize: true),
            const SizedBox(height: 4),
            _line('Name', c.name.trim().isEmpty ? '—' : c.name.trim(),
                big: true),
            const SizedBox(height: 2),
            _line(
              'Post',
              c.designation.trim().isEmpty ? '—' : c.designation.trim(),
            ),
            if (c.district.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              _line('District', c.district.trim()),
            ],
            const SizedBox(height: 8),
            if (c.hasPhone)
              InkWell(
                onTap: onCall,
                onLongPress: onCopy,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.purple.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone, color: AppTheme.purple, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mobile: ${c.phoneDisplay}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy number',
                        onPressed: onCopy,
                        icon: const Icon(Icons.copy, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Call',
                        onPressed: onCall,
                        icon: const Icon(Icons.call, color: Colors.green, size: 22),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                'Mobile: —  (Edit se number add karein)',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value, {bool emphasize = false, bool big = false}) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              fontSize: big ? 14 : 13,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: emphasize ? AppTheme.purple : AppTheme.ink,
              fontWeight: FontWeight.w800,
              fontSize: big ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
