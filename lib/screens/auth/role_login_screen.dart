import 'package:flutter/material.dart';

import '../../models/board_post.dart';
import '../../models/board_post_role_mapper.dart';
import '../../models/club_role.dart';
import '../../models/member.dart';
import '../../services/board_store.dart';
import '../../services/member_store.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../shell/main_shell.dart';

enum _LoginTab { allPosts, byMember, manual }

class RoleLoginScreen extends StatefulWidget {
  const RoleLoginScreen({super.key});

  @override
  State<RoleLoginScreen> createState() => _RoleLoginScreenState();
}

class _RoleLoginScreenState extends State<RoleLoginScreen> {
  bool _loading = true;
  bool _busy = false;
  _LoginTab _tab = _LoginTab.allPosts;

  List<Member> _members = [];
  List<BoardPost> _allPosts = [];
  Member? _member;
  List<BoardPost> _myPosts = [];
  BoardPost? _selectedPost;

  final _nameCtrl = TextEditingController();
  ClubRole _manualRole = ClubRole.member;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final members = await MemberStore.ensureLoaded();
    final posts = await BoardStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _members = List.of(members)
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      _allPosts = List.of(posts);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onMemberPicked(Member? m) {
    final posts = m == null ? <BoardPost>[] : BoardStore.postsForMember(m.id);
    setState(() {
      _member = m;
      _myPosts = posts;
      _selectedPost = posts.isEmpty ? null : posts.first;
      if (m != null) _nameCtrl.text = m.displayName;
    });
  }

  String _holderName(BoardPost post) {
    if (!post.hasMember) return 'Vacant';
    return MemberStore.byId(post.memberId)?.displayName ?? 'Assigned';
  }

  Future<void> _loginAsPost(BoardPost post) async {
    setState(() => _busy = true);
    final role = BoardPostRoleMapper.roleForPost(post);
    final holder = post.hasMember ? MemberStore.byId(post.memberId) : null;
    final name = (holder?.displayName.trim().isNotEmpty == true)
        ? holder!.displayName.trim()
        : 'Member';

    await SessionService.login(
      name: name,
      role: role,
      memberId: post.memberId,
      boardPostId: post.id,
      boardPostTitle: post.title,
    );

    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  Future<void> _loginAsMemberDesk() async {
    setState(() => _busy = true);
    await SessionService.login(
      name: 'Samanya Member',
      role: ClubRole.member,
      memberId: '',
      boardPostId: '',
      boardPostTitle: '',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  Future<void> _continueMemberOrManual() async {
    setState(() => _busy = true);

    if (_tab == _LoginTab.byMember) {
      if (_member == null) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pehle naam choose karein')),
        );
        return;
      }
      final post = _selectedPost;
      final role = post != null
          ? BoardPostRoleMapper.roleForPost(post)
          : ClubRole.member;
      await SessionService.login(
        name: _member!.displayName,
        role: role,
        memberId: _member!.id,
        boardPostId: post?.id ?? '',
        boardPostTitle: post?.title ?? '',
      );
    } else {
      final name = _nameCtrl.text.trim();
      await SessionService.login(
        name: name.isEmpty ? _manualRole.label : name,
        role: _manualRole,
      );
    }

    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppTheme.bg,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _loading
                      ? const SizedBox(
                          height: 160,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: AppTheme.purple,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.pets, color: AppTheme.goldSoft),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Lions Club Pro',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        'Sabhi posts ke desks — login & setup',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SegmentedButton<_LoginTab>(
                              segments: const [
                                ButtonSegment(
                                  value: _LoginTab.allPosts,
                                  label: Text('Sabhi Posts'),
                                  icon: Icon(Icons.desk_outlined, size: 18),
                                ),
                                ButtonSegment(
                                  value: _LoginTab.byMember,
                                  label: Text('Member'),
                                  icon: Icon(Icons.person_outline, size: 18),
                                ),
                                ButtonSegment(
                                  value: _LoginTab.manual,
                                  label: Text('Manual'),
                                  icon: Icon(Icons.tune, size: 18),
                                ),
                              ],
                              selected: {_tab},
                              onSelectionChanged: (s) => setState(() => _tab = s.first),
                            ),
                            const SizedBox(height: 16),
                            if (_tab == _LoginTab.allPosts) _allPostsPanel(),
                            if (_tab == _LoginTab.byMember) _memberPanel(),
                            if (_tab == _LoginTab.manual) _manualPanel(),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _allPostsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Kisi bhi post par tap karein — uska desk khulega. Desk banao / dekho.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.35),
        ),
        const SizedBox(height: 10),
        Card(
          color: AppTheme.purple.withValues(alpha: 0.06),
          child: ListTile(
            leading: const Icon(Icons.groups_outlined, color: AppTheme.purple),
            title: const Text(
              'Samanya Member Desk',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Agami programmes, photos, club updates'),
            trailing: const Icon(Icons.login),
            onTap: _busy ? null : _loginAsMemberDesk,
          ),
        ),
        const SizedBox(height: 8),
        if (_allPosts.isEmpty)
          const Text('Board posts nahi mile — Board Members check karein.')
        else
          ..._allPosts.map((post) {
            final role = BoardPostRoleMapper.roleForPost(post);
            final holder = _holderName(post);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.purple.withValues(alpha: 0.12),
                    child: Text(
                      post.title.isEmpty ? '?' : post.title[0],
                      style: const TextStyle(
                        color: AppTheme.purple,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    post.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('$holder · Desk access: ${role.label}'),
                  trailing: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  onTap: _busy ? null : () => _loginAsPost(post),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _memberPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<Member>(
          initialValue: _member,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Aapka naam (Members se)',
            prefixIcon: Icon(Icons.person_outline),
          ),
          items: [
            for (final m in _members)
              DropdownMenuItem(
                value: m,
                child: Text(m.displayName, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _onMemberPicked,
        ),
        const SizedBox(height: 12),
        if (_member != null && _myPosts.isEmpty)
          Text(
            'Is member ki board post nahi — Member Desk khulega.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          )
        else if (_myPosts.isNotEmpty)
          DropdownButtonFormField<BoardPost>(
            initialValue: _selectedPost,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Board Post',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: [
              for (final p in _myPosts)
                DropdownMenuItem(
                  value: p,
                  child: Text(p.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (p) => setState(() => _selectedPost = p),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _continueMemberOrManual,
          child: const Text('Mera Desk kholo'),
        ),
      ],
    );
  }

  Widget _manualPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Your name',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ClubRole>(
          initialValue: _manualRole,
          decoration: const InputDecoration(
            labelText: 'Login as (role)',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          items: [
            for (final r in ClubRole.values)
              DropdownMenuItem(value: r, child: Text(r.label)),
          ],
          onChanged: (r) {
            if (r != null) setState(() => _manualRole = r);
          },
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _continueMemberOrManual,
          child: const Text('Mera Desk kholo'),
        ),
      ],
    );
  }
}
