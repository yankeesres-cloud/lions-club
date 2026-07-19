import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/club_role.dart';
import '../../models/guest_post.dart';
import '../../models/member.dart';
import '../../services/guest_store.dart';
import '../../services/member_photo_service.dart';
import '../../services/member_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/member_photo.dart';
import '../../widgets/member_picker.dart';

class GuestListScreen extends StatefulWidget {
  const GuestListScreen({super.key, required this.role});

  final ClubRole role;

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen> {
  List<GuestPost> _posts = [];
  List<Member> _members = [];
  bool _loading = true;

  /// Module already role-gated.
  bool get _canEdit => true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final posts = await GuestStore.load();
    final members = await MemberStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _posts = posts;
      _members = members;
      _loading = false;
    });
  }

  String _displayName(GuestPost post) {
    if (post.memberId.isNotEmpty) {
      try {
        return _members.firstWhere((m) => m.id == post.memberId).displayName;
      } catch (_) {}
    }
    return post.name.trim().isEmpty ? 'Guest details add karein' : post.name.trim();
  }

  String _displayPhone(GuestPost post) {
    if (post.memberId.isNotEmpty) {
      try {
        final m = _members.firstWhere((m) => m.id == post.memberId);
        if (m.primaryPhone.isNotEmpty) return m.primaryPhone;
      } catch (_) {}
    }
    return post.phone.trim();
  }

  String _displayPhoto(GuestPost post) {
    if (post.memberId.isNotEmpty) {
      try {
        final m = _members.firstWhere((m) => m.id == post.memberId);
        if (m.primaryPhoto.isNotEmpty) return m.primaryPhoto;
      } catch (_) {}
    }
    return post.photo.trim();
  }

  Future<void> _editGuest(GuestPost post) async {
    if (!_canEdit) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GuestDetailFormScreen(
          post: post,
          members: _members,
        ),
      ),
    );
    if (changed == true) await _reload();
  }

  Future<void> _addPost() async {
    final ctrl = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New guest post'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Post / designation',
            hintText: 'e.g. Past District Governor',
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
    final t = title?.trim() ?? '';
    ctrl.dispose();
    if (t.isEmpty) return;
    final post = await GuestStore.addPost(t);
    await _reload();
    if (!mounted) return;
    // Seedhone ke baad turant details form.
    await _editGuest(post);
  }

  Future<void> _deletePost(GuestPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete guest post?'),
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
    await GuestStore.deletePost(post.id);
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
                  'Guest List (${_posts.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'DG, ID, IP wagairah — name/phone yahan save, ya Members se link',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                if (_canEdit) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _addPost,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Guest Post'),
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
                final photo = _displayPhoto(post);
                final phone = _displayPhone(post);
                final name = _displayName(post);
                final hasPhoto = photo.isNotEmpty && File(photo).existsSync();

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.purple.withValues(alpha: 0.12),
                      backgroundImage: hasPhoto ? FileImage(File(photo)) : null,
                      child: hasPhoto
                          ? null
                          : Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.purpleDeep,
                              ),
                            ),
                    ),
                    title: Text(
                      post.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    subtitle: Text(
                      [
                        name,
                        if (phone.isNotEmpty) phone,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _editGuest(post),
                    trailing: _canEdit
                        ? PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _editGuest(post);
                              if (v == 'clear') {
                                GuestStore.clearPerson(post.id).then((_) => _reload());
                              }
                              if (v == 'delete') _deletePost(post);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit guest')),
                              if (post.hasPerson)
                                const PopupMenuItem(value: 'clear', child: Text('Clear person')),
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

class GuestDetailFormScreen extends StatefulWidget {
  const GuestDetailFormScreen({
    super.key,
    required this.post,
    required this.members,
  });

  final GuestPost post;
  final List<Member> members;

  @override
  State<GuestDetailFormScreen> createState() => _GuestDetailFormScreenState();
}

class _GuestDetailFormScreenState extends State<GuestDetailFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _notes;
  late String _photo;
  late String _memberId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    _name = TextEditingController(text: p.name);
    _phone = TextEditingController(text: p.phone);
    _notes = TextEditingController(text: p.notes);
    _photo = p.photo;
    _memberId = p.memberId;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickFromMembers() async {
    final members = widget.members.isEmpty
        ? await MemberStore.ensureLoaded()
        : widget.members;
    if (!mounted) return;
    final selected = await pickClubMember(
      context: context,
      members: members,
      currentId: _memberId,
      title: 'Club member se link (optional)',
      allowClear: _memberId.isNotEmpty,
    );
    if (!mounted || selected == null) return;
    if (selected.id.isEmpty) {
      setState(() => _memberId = '');
      return;
    }
    setState(() {
      _memberId = selected.id;
      if (_name.text.trim().isEmpty) _name.text = selected.displayName;
      if (_phone.text.trim().isEmpty) _phone.text = selected.primaryPhone;
      if (_photo.isEmpty) _photo = selected.primaryPhoto;
    });
  }

  Future<void> _setPhoto({required bool camera}) async {
    try {
      final path = camera
          ? await MemberPhotoService.pickFromCamera(
              memberId: 'guest_${widget.post.id}',
              side: 'G',
            )
          : await MemberPhotoService.pickFromGallery(
              memberId: 'guest_${widget.post.id}',
              side: 'G',
            );
      if (!mounted || path == null) return;
      setState(() => _photo = path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo fail: $e')),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = widget.post.copyWith(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      notes: _notes.text.trim(),
      photo: _photo,
      memberId: _memberId,
    );
    await GuestStore.upsert(updated);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.post.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Guest / dignitary details — har post pe ek vyakti',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickFromMembers,
            icon: const Icon(Icons.groups_outlined),
            label: Text(
              _memberId.isEmpty ? 'Members list se select (optional)' : 'Member linked — change',
            ),
          ),
          const SizedBox(height: 12),
          MemberPhotoPickerTile(
            title: 'Guest photo',
            photoPath: _photo,
            onGallery: () => _setPhoto(camera: false),
            onCamera: () => _setPhoto(camera: true),
            onClear: () => setState(() => _photo = ''),
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (club / district / visit)',
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
            label: const Text('Save Guest'),
          ),
        ],
      ),
    );
  }
}
