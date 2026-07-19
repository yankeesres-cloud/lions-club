import 'package:flutter/material.dart';

import '../models/guest_post.dart';
import '../models/member.dart';
import '../services/board_store.dart';
import '../services/club_contact_store.dart';
import '../services/guest_store.dart';
import '../services/member_store.dart';
import '../theme/app_theme.dart';
import '../widgets/member_photo.dart';

enum DeskPickScope {
  member,
  board,
  guest,
  anyClub,
}

class DeskPickResult {
  const DeskPickResult({
    required this.scope,
    required this.displayName,
    this.memberId = '',
    this.boardPostId = '',
    this.boardPostTitle = '',
    this.subtitle = '',
  });

  final DeskPickScope scope;
  final String displayName;
  final String memberId;
  final String boardPostId;
  final String boardPostTitle;
  final String subtitle;
}

/// Desk select — Member / Board / Guest / Any club (alag search).
Future<DeskPickResult?> pickDeskPerson({
  required BuildContext context,
  String currentMemberId = '',
}) async {
  await Future.wait([
    MemberStore.ensureLoaded(),
    BoardStore.ensureLoaded(),
    GuestStore.ensureLoaded(),
    ClubContactStore.ensureLoaded(),
  ]);
  if (!context.mounted) return null;

  return showDialog<DeskPickResult>(
    context: context,
    builder: (ctx) => _DeskSelectDialog(currentMemberId: currentMemberId),
  );
}

class _DeskSelectDialog extends StatefulWidget {
  const _DeskSelectDialog({required this.currentMemberId});

  final String currentMemberId;

  @override
  State<_DeskSelectDialog> createState() => _DeskSelectDialogState();
}

class _DeskSelectDialogState extends State<_DeskSelectDialog> {
  DeskPickScope _scope = DeskPickScope.member;
  final _searchMember = TextEditingController();
  final _searchBoard = TextEditingController();
  final _searchGuest = TextEditingController();
  final _searchClub = TextEditingController();

  @override
  void dispose() {
    _searchMember.dispose();
    _searchBoard.dispose();
    _searchGuest.dispose();
    _searchClub.dispose();
    super.dispose();
  }

  bool _isBoard(Member m) => BoardStore.postsForMember(m.id).isNotEmpty;

  List<Member> get _allMembers {
    final seen = <String>{};
    final out = <Member>[];
    for (final m in MemberStore.current) {
      if (m.id.trim().isEmpty || seen.contains(m.id)) continue;
      seen.add(m.id);
      out.add(m);
    }
    out.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return out;
  }

  TextEditingController get _activeSearch {
    switch (_scope) {
      case DeskPickScope.member:
        return _searchMember;
      case DeskPickScope.board:
        return _searchBoard;
      case DeskPickScope.guest:
        return _searchGuest;
      case DeskPickScope.anyClub:
        return _searchClub;
    }
  }

  String get _searchHint {
    switch (_scope) {
      case DeskPickScope.member:
        return 'Member search — naam / phone…';
      case DeskPickScope.board:
        return 'Board member search — naam / post…';
      case DeskPickScope.guest:
        return 'Guest search — naam / post…';
      case DeskPickScope.anyClub:
        return 'Any club search — naam / club / city…';
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _allMembers;
    final boardN = members.where(_isBoard).length;
    final memberN = members.length - boardN;
    final guestN = GuestStore.current.where((g) => g.hasPerson).length;
    final clubN = ClubContactStore.current.length;

    return AlertDialog(
      title: const Text('Desk select'),
      content: SizedBox(
        width: 520,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ~3 lines of options
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _scopeChip(
                  DeskPickScope.member,
                  'Member',
                  memberN,
                  Icons.person_outline,
                ),
                _scopeChip(
                  DeskPickScope.board,
                  'Board member',
                  boardN,
                  Icons.badge_outlined,
                ),
                _scopeChip(
                  DeskPickScope.guest,
                  'Guest member',
                  guestN,
                  Icons.handshake_outlined,
                ),
                _scopeChip(
                  DeskPickScope.anyClub,
                  'Any club member',
                  clubN,
                  Icons.public_outlined,
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _activeSearch,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _searchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _activeSearch.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _activeSearch.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _listBody()),
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

  Widget _scopeChip(
    DeskPickScope scope,
    String label,
    int count,
    IconData icon,
  ) {
    final on = _scope == scope;
    return FilterChip(
      selected: on,
      showCheckmark: false,
      avatar: Icon(icon, size: 16, color: on ? Colors.white : null),
      label: Text(
        '$label ($count)',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: on ? Colors.white : null,
        ),
      ),
      selectedColor: AppTheme.purple,
      onSelected: (_) => setState(() => _scope = scope),
    );
  }

  Widget _listBody() {
    switch (_scope) {
      case DeskPickScope.member:
        return _memberList(boardOnly: false);
      case DeskPickScope.board:
        return _memberList(boardOnly: true);
      case DeskPickScope.guest:
        return _guestList();
      case DeskPickScope.anyClub:
        return _clubContactList();
    }
  }

  Widget _memberList({required bool boardOnly}) {
    final q = (boardOnly ? _searchBoard : _searchMember).text.trim().toLowerCase();
    final list = _allMembers.where((m) {
      final isB = _isBoard(m);
      if (boardOnly && !isB) return false;
      if (!boardOnly && isB) return false;
      if (q.isEmpty) return true;
      if (m.matchesQuery(q)) return true;
      if (boardOnly) {
        return BoardStore.postsForMember(m.id).any(
          (p) => p.title.toLowerCase().contains(q),
        );
      }
      return false;
    }).toList();

    if (list.isEmpty) {
      return Center(
        child: Text(
          boardOnly
              ? 'Koi board member nahi / search match nahi'
              : 'Koi member nahi / search match nahi',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) {
        final m = list[i];
        final selected = m.id == widget.currentMemberId;
        final posts = BoardStore.postsForMember(m.id)
            .map((p) => p.title)
            .where((t) => t.trim().isNotEmpty)
            .join(' · ');
        return ListTile(
          selected: selected,
          leading: MemberFaceAvatar(member: m, radius: 18),
          title: Text(
            m.displayName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            [
              if (posts.isNotEmpty) posts,
              m.gender.label,
              if (m.primaryPhone.isNotEmpty) m.primaryPhone,
            ].join(' · '),
          ),
          trailing: selected
              ? const Icon(Icons.check_circle, color: AppTheme.purple)
              : null,
          onTap: () {
            if (boardOnly) {
              final seats = BoardStore.postsForMember(m.id);
              if (seats.length == 1) {
                Navigator.pop(
                  context,
                  DeskPickResult(
                    scope: DeskPickScope.board,
                    displayName: m.displayName,
                    memberId: m.id,
                    boardPostId: seats.first.id,
                    boardPostTitle: seats.first.title,
                    subtitle: seats.first.title,
                  ),
                );
                return;
              }
            }
            Navigator.pop(
              context,
              DeskPickResult(
                scope: boardOnly ? DeskPickScope.board : DeskPickScope.member,
                displayName: m.displayName,
                memberId: m.id,
                subtitle: boardOnly ? 'Board' : 'Member',
              ),
            );
          },
        );
      },
    );
  }

  Widget _guestList() {
    final q = _searchGuest.text.trim().toLowerCase();
    final rows = <({GuestPost post, String name, String memberId})>[];
    for (final g in GuestStore.current) {
      if (!g.hasPerson) continue;
      var name = g.name.trim();
      var mid = g.memberId.trim();
      if (mid.isNotEmpty) {
        final m = MemberStore.byId(mid);
        if (m != null && m.displayName.trim().isNotEmpty) {
          name = m.displayName.trim();
        }
      }
      if (name.isEmpty) name = g.title.trim();
      if (name.isEmpty) continue;
      final hay = '$name ${g.title} ${g.phone} ${g.notes}'.toLowerCase();
      if (q.isNotEmpty && !hay.contains(q)) continue;
      rows.add((post: g, name: name, memberId: mid));
    }
    rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (rows.isEmpty) {
      return Center(
        child: Text(
          'Koi guest nahi / Guests module mein add karein',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      );
    }

    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final r = rows[i];
        final m = r.memberId.isEmpty ? null : MemberStore.byId(r.memberId);
        return ListTile(
          leading: m != null
              ? MemberFaceAvatar(member: m, radius: 18)
              : CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.orange.shade100,
                  child: Icon(Icons.handshake_outlined,
                      size: 18, color: Colors.orange.shade800),
                ),
          title: Text(
            r.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            [
              r.post.title.trim().isEmpty ? 'Guest' : r.post.title.trim(),
              if (r.post.phone.trim().isNotEmpty) r.post.phone.trim(),
            ].join(' · '),
          ),
          onTap: () => Navigator.pop(
            context,
            DeskPickResult(
              scope: DeskPickScope.guest,
              displayName: r.name,
              memberId: r.memberId,
              boardPostTitle: r.post.title.trim().isEmpty
                  ? 'Guest'
                  : 'Guest · ${r.post.title.trim()}',
              subtitle: r.post.title,
            ),
          ),
        );
      },
    );
  }

  Widget _clubContactList() {
    final q = _searchClub.text.trim();
    final list = ClubContactStore.current
        .where((c) => c.matchesQuery(q))
        .toList();

    if (list.isEmpty) {
      return Center(
        child: Text(
          'Koi club contact nahi / Directory mein add karein',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) {
        final c = list[i];
        return ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.teal.shade50,
            child: Icon(Icons.public_outlined,
                size: 18, color: Colors.teal.shade800),
          ),
          title: Text(
            c.displayName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            [
              if (c.clubName.trim().isNotEmpty) c.clubName.trim(),
              if (c.designation.trim().isNotEmpty) c.designation.trim(),
              if (c.phoneDisplay.isNotEmpty) c.phoneDisplay,
            ].join(' · '),
          ),
          onTap: () {
            final club = c.clubName.trim();
            final desig = c.designation.trim();
            final post = [
              if (club.isNotEmpty) club,
              if (desig.isNotEmpty) desig,
            ].join(' · ');
            Navigator.pop(
              context,
              DeskPickResult(
                scope: DeskPickScope.anyClub,
                displayName: c.displayName,
                boardPostTitle:
                    post.isEmpty ? 'Other club' : 'Club · $post',
                subtitle: club,
              ),
            );
          },
        );
      },
    );
  }
}
