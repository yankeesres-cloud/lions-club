import 'package:flutter/material.dart';

import '../models/member.dart';
import '../theme/app_theme.dart';
import '../widgets/member_photo.dart';

/// Reliable member picker (Dialog) — macOS bottom-sheet issues avoid.
Future<Member?> pickClubMember({
  required BuildContext context,
  required List<Member> members,
  String currentId = '',
  String title = 'Select member',
  bool allowClear = true,
}) async {
  if (members.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pehle Members mein list add / Excel load karein'),
      ),
    );
    return null;
  }

  return showDialog<Member?>(
    context: context,
    builder: (ctx) => _MemberPickDialog(
      members: members,
      currentId: currentId,
      title: title,
      allowClear: allowClear,
    ),
  );
}

/// Multi-select (e.g. Program PC 1–4). Returns null if cancelled.
Future<List<String>?> pickClubMembers({
  required BuildContext context,
  required List<Member> members,
  List<String> selectedIds = const [],
  String title = 'Select members',
  int maxSelection = 4,
}) async {
  if (members.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pehle Members mein list add / Excel load karein'),
      ),
    );
    return null;
  }

  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => _MultiMemberPickDialog(
      members: members,
      selectedIds: selectedIds,
      title: title,
      maxSelection: maxSelection,
    ),
  );
}

class _MemberPickDialog extends StatefulWidget {
  const _MemberPickDialog({
    required this.members,
    required this.currentId,
    required this.title,
    required this.allowClear,
  });

  final List<Member> members;
  final String currentId;
  final String title;
  final bool allowClear;

  @override
  State<_MemberPickDialog> createState() => _MemberPickDialogState();
}

class _MemberPickDialogState extends State<_MemberPickDialog> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final list = widget.members.where((m) => m.matchesQuery(q)).toList()
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search…',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
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
            if (widget.allowClear && widget.currentId.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context, const Member(id: '')),
                  icon: const Icon(Icons.person_off_outlined),
                  label: const Text('Clear selection'),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        'Koi member nahi',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final m = list[i];
                        final selected = m.id == widget.currentId;
                        return ListTile(
                          selected: selected,
                          leading: MemberFaceAvatar(member: m, radius: 18),
                          title: Text(
                            m.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              m.gender.label,
                              if (m.primaryPhone.isNotEmpty) m.primaryPhone,
                            ].join(' · '),
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_circle, color: AppTheme.purple)
                              : null,
                          onTap: () => Navigator.pop(context, m),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _MultiMemberPickDialog extends StatefulWidget {
  const _MultiMemberPickDialog({
    required this.members,
    required this.selectedIds,
    required this.title,
    required this.maxSelection,
  });

  final List<Member> members;
  final List<String> selectedIds;
  final String title;
  final int maxSelection;

  @override
  State<_MultiMemberPickDialog> createState() => _MultiMemberPickDialogState();
}

class _MultiMemberPickDialogState extends State<_MultiMemberPickDialog> {
  final _search = TextEditingController();
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {
      for (final id in widget.selectedIds)
        if (id.trim().isNotEmpty) id.trim(),
    };
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(Member m) {
    setState(() {
      if (_selected.contains(m.id)) {
        _selected.remove(m.id);
      } else if (_selected.length < widget.maxSelection) {
        _selected.add(m.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final list = widget.members.where((m) => m.matchesQuery(q)).toList()
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_selected.length} / ${widget.maxSelection} select',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.purple,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search…',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
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
            const SizedBox(height: 8),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        'Koi member nahi',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final m = list[i];
                        final selected = _selected.contains(m.id);
                        final atMax =
                            !selected && _selected.length >= widget.maxSelection;
                        return CheckboxListTile(
                          value: selected,
                          onChanged: atMax ? null : (_) => _toggle(m),
                          secondary: MemberFaceAvatar(member: m, radius: 18),
                          title: Text(
                            m.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              m.gender.label,
                              if (m.primaryPhone.isNotEmpty) m.primaryPhone,
                            ].join(' · '),
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, <String>[]),
          child: const Text('Clear'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected.toList()),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
