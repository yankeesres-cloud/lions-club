import 'package:flutter/material.dart';

import '../../models/board_post.dart';
import '../../models/club_role.dart';
import '../../models/member.dart';
import '../../services/board_store.dart';
import '../../services/member_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/member_photo.dart';
import '../../widgets/member_picker.dart';

class BoardMembersScreen extends StatefulWidget {
  const BoardMembersScreen({super.key, required this.role});

  final ClubRole role;

  @override
  State<BoardMembersScreen> createState() => _BoardMembersScreenState();
}

class _BoardMembersScreenState extends State<BoardMembersScreen> {
  List<BoardPost> _posts = [];
  List<Member> _members = [];
  bool _loading = true;

  /// Module already role-gated — har login board assign kar sake.
  bool get _canEdit => true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final posts = await BoardStore.load();
    final members = await MemberStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _posts = posts;
      _members = members;
      _loading = false;
    });
  }

  Member? _memberOf(BoardPost post) {
    if (!post.hasMember) return null;
    try {
      return _members.firstWhere((m) => m.id == post.memberId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickMember(BoardPost post) async {
    if (!_canEdit) return;
    // Fresh members — stale empty list avoid.
    final members = await MemberStore.ensureLoaded();
    if (!mounted) return;
    setState(() => _members = members);

    final selected = await pickClubMember(
      context: context,
      members: members,
      currentId: post.memberId,
      title: 'Select for ${post.title}',
      allowClear: post.hasMember,
    );
    if (!mounted || selected == null) return;
    if (selected.id.isEmpty) {
      await BoardStore.clearMember(post.id);
    } else {
      await BoardStore.assignMember(postId: post.id, memberId: selected.id);
    }
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selected.id.isEmpty
              ? '${post.title}: member clear'
              : '${post.title}: ${selected.displayName}',
        ),
      ),
    );
  }

  Future<void> _addPost() async {
    final ctrl = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New post add'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Post name',
            hintText: 'e.g. ZONE CHAIRPERSON',
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
    if (title == null || title.isEmpty) return;
    await BoardStore.addPost(title);
    await _reload();
  }

  Future<void> _deletePost(BoardPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: Text('"${post.title}" list se hat jayega.'),
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
    await BoardStore.deletePost(post.id);
    await _reload();
  }

  Future<void> _renamePost(BoardPost post) async {
    final ctrl = TextEditingController(text: post.title);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename post'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Post name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (title == null || title.isEmpty) return;
    await BoardStore.renamePost(post.id, title);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

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
                  'Board Members (${_posts.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                ),
                const SizedBox(height: 4),
                  Text(
                  'Har post pe sirf ek vyakti (Members list se). Pati/patni alag members hain.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                if (_canEdit) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _addPost,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Post'),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _posts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final post = _posts[i];
                final member = _memberOf(post);
                final orphan = post.hasMember && member == null;

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    leading: member != null
                        ? MemberFaceAvatar(member: member, radius: 22)
                        : CircleAvatar(
                            backgroundColor: AppTheme.goldSoft.withValues(alpha: 0.45),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.purpleDeep,
                                fontSize: 12,
                              ),
                            ),
                          ),
                    title: Text(
                      post.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    subtitle: Text(
                      member != null
                          ? member.displayName
                          : orphan
                              ? 'Member deleted — dubara select karein'
                              : 'Tap to select from Members',
                      style: TextStyle(
                        color: orphan ? Colors.red.shade700 : Colors.grey.shade700,
                      ),
                    ),
                    onTap: _canEdit ? () => _pickMember(post) : null,
                    trailing: _canEdit
                        ? PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'select') _pickMember(post);
                              if (v == 'clear') {
                                BoardStore.clearMember(post.id).then((_) => _reload());
                              }
                              if (v == 'rename') _renamePost(post);
                              if (v == 'delete') _deletePost(post);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'select', child: Text('Select member')),
                              if (post.hasMember)
                                const PopupMenuItem(value: 'clear', child: Text('Clear member')),
                              const PopupMenuItem(value: 'rename', child: Text('Rename post')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete post')),
                            ],
                          )
                        : const Icon(Icons.chevron_right),
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
