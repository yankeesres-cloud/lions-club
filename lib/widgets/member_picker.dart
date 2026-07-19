import 'package:flutter/material.dart';

import '../models/member.dart';
import '../services/board_store.dart';
import '../theme/app_theme.dart';
import '../widgets/member_photo.dart';

/// Reliable member picker (Dialog) — macOS bottom-sheet issues avoid.
Future<Member?> pickClubMember({
  required BuildContext context,
  required List<Member> members,
  String currentId = '',
  String title = 'Select member',
  bool allowClear = true,
  /// Desk select: Sabhi + Board — do search / scope.
  bool dualScopeSearch = false,
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
      dualScopeSearch: dualScopeSearch,
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

enum _PickScope { all, board }

class _MemberPickDialog extends StatefulWidget {
  const _MemberPickDialog({
    required this.members,
    required this.currentId,
    required this.title,
    required this.allowClear,
    this.dualScopeSearch = false,
  });

  final List<Member> members;
  final String currentId;
  final String title;
  final bool allowClear;
  final bool dualScopeSearch;

  @override
  State<_MemberPickDialog> createState() => _MemberPickDialogState();
}

class _MemberPickDialogState extends State<_MemberPickDialog> {
  final _searchAll = TextEditingController();
  final _searchBoard = TextEditingController();
  _PickScope _scope = _PickScope.all;

  @override
  void dispose() {
    _searchAll.dispose();
    _searchBoard.dispose();
    super.dispose();
  }

  bool _isBoardMember(Member m) =>
      BoardStore.postsForMember(m.id).isNotEmpty;

  String _boardSubtitle(Member m) {
    final posts = BoardStore.postsForMember(m.id)
        .map((p) => p.title.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final bits = <String>[
      if (posts.isNotEmpty) posts.join(' · '),
      m.gender.label,
      if (m.primaryPhone.isNotEmpty) m.primaryPhone,
    ];
    return bits.join(' · ');
  }

  List<Member> _filtered() {
    final boardOnly = widget.dualScopeSearch && _scope == _PickScope.board;
    final q = (boardOnly ? _searchBoard : _searchAll).text.trim().toLowerCase();
    var list = widget.members.where((m) {
      if (boardOnly && !_isBoardMember(m)) return false;
      return m.matchesQuery(q) ||
          (boardOnly &&
              BoardStore.postsForMember(m.id).any(
                (p) => p.title.toLowerCase().contains(q),
              ));
    }).toList();
    list.sort(
      (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return list;
  }

  Widget _searchField({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      autofocus: true,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.clear),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered();
    final boardCount =
        widget.members.where(_isBoardMember).length;

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        height: widget.dualScopeSearch ? 480 : 420,
        child: Column(
          children: [
            if (widget.dualScopeSearch) ...[
              SegmentedButton<_PickScope>(
                segments: [
                  ButtonSegment(
                    value: _PickScope.all,
                    label: Text('Sabhi (${widget.members.length})'),
                    icon: const Icon(Icons.groups_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: _PickScope.board,
                    label: Text('Board ($boardCount)'),
                    icon: const Icon(Icons.badge_outlined, size: 18),
                  ),
                ],
                selected: {_scope},
                onSelectionChanged: (s) {
                  setState(() => _scope = s.first);
                },
              ),
              const SizedBox(height: 10),
              if (_scope == _PickScope.all)
                _searchField(
                  controller: _searchAll,
                  hint: 'Sabhi members search — naam / phone…',
                )
              else
                _searchField(
                  controller: _searchBoard,
                  hint: 'Board members search — naam / post…',
                ),
            ] else
              _searchField(
                controller: _searchAll,
                hint: 'Search…',
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
                        _scope == _PickScope.board
                            ? 'Koi board member nahi / search match nahi'
                            : 'Koi member nahi',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final m = list[i];
                        final selected = m.id == widget.currentId;
                        final isBoard = _isBoardMember(m);
                        return ListTile(
                          selected: selected,
                          leading: MemberFaceAvatar(member: m, radius: 18),
                          title: Text(
                            m.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            widget.dualScopeSearch && isBoard
                                ? _boardSubtitle(m)
                                : [
                                    m.gender.label,
                                    if (m.primaryPhone.isNotEmpty)
                                      m.primaryPhone,
                                  ].join(' · '),
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_circle, color: AppTheme.purple)
                              : (isBoard && widget.dualScopeSearch
                                  ? Icon(
                                      Icons.badge_outlined,
                                      size: 18,
                                      color: Colors.grey.shade600,
                                    )
                                  : null),
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
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selectedIds};
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < widget.maxSelection) {
        _selected.add(id);
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
                        final on = _selected.contains(m.id);
                        return CheckboxListTile(
                          value: on,
                          secondary: MemberFaceAvatar(member: m, radius: 18),
                          title: Text(
                            m.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(m.primaryPhone),
                          onChanged: (_) => _toggle(m.id),
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
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected.toList()),
          child: Text('OK (${_selected.length})'),
        ),
      ],
    );
  }
}
