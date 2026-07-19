import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/club_role.dart';
import '../../models/member.dart';
import '../../models/planned_program.dart';
import '../../models/post_desk.dart';
import '../../models/role_desk_profile.dart';
import '../../models/board_post.dart';
import '../../models/board_post_role_mapper.dart';
import '../../services/accounts_store.dart';
import '../../services/ai_draft_service.dart';
import '../../services/board_store.dart';
import '../../services/club_settings_store.dart';
import '../../services/desk_draft_store.dart';
import '../../services/gallery_store.dart';
import '../../services/member_store.dart';
import '../../services/planner_store.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/board_notice_box.dart';
import '../../widgets/date_check_bar.dart';
import '../../widgets/desk_select_dialog.dart';
import '../accounts/accounts_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../gallery/gallery_screen.dart';
import '../shell/main_shell.dart';

/// Har login / post ka alag personal desk home.
class PostDeskHubScreen extends StatefulWidget {
  const PostDeskHubScreen({
    super.key,
    required this.role,
    required this.userName,
    this.boardPostTitle = '',
    this.boardPostId = '',
    this.memberId = '',
    this.onOpenModule,
  });

  final ClubRole role;
  final String userName;
  final String boardPostTitle;
  final String boardPostId;
  final String memberId;
  final ValueChanged<AppModule>? onOpenModule;

  @override
  State<PostDeskHubScreen> createState() => _PostDeskHubScreenState();
}

class _PostDeskHubScreenState extends State<PostDeskHubScreen> {
  bool _loading = true;
  List<PlannedProgram> _upcoming = [];
  List<GalleryPhoto> _photos = [];
  List<DeskDraft> _activity = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    await Future.wait([
      PlannerStore.ensureLoaded(),
      GalleryStore.ensureLoaded(),
      AccountsStore.ensureLoaded(),
      BoardStore.ensureLoaded(),
      MemberStore.ensureLoaded(),
      ClubSettingsStore.load(),
    ]);
    // Demo check members auto-seed band — delete ke baad wapas na aayein.
    await MemberStore.removeOccasionCheckDemos();
    final activity = await DeskDraftStore.loadRecent();
    if (!mounted) return;
    setState(() {
      _upcoming = PlannerStore.upcoming.take(5).toList();
      _photos = GalleryStore.current.take(12).toList();
      _activity = activity;
      _loading = false;
    });
  }

  bool get _isTreasurer =>
      widget.role == ClubRole.treasurer || widget.role == ClubRole.jointTreasurer;

  bool get _seeAll => PostDeskAccess.roleSeesAll(widget.role);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final club = ClubSettingsStore.current;

    // AppBar ke neeche Board notice (5 din); neeche club wall.
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BoardNoticeBox(
            userName: widget.userName,
            memberId: widget.memberId,
            boardPostTitle: widget.boardPostTitle,
          ),
          const DateCheckBar(),
          Expanded(
            child: DashboardScreen(
              role: widget.role,
              userName: widget.userName,
              club: club,
              memberId: widget.memberId,
              embedded: true,
              onOpenModule: (m) {
                if (widget.onOpenModule != null) {
                  widget.onOpenModule!(m);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Legacy pink header — unused.
  // ignore: unused_element
  Widget _deskSelectorHeader() {
    final mid = widget.memberId.trim();
    final selected = mid.isEmpty ? null : MemberStore.byId(mid);
    final seats = selected == null
        ? const <BoardPost>[]
        : BoardStore.postsForMember(selected.id);
    final pageName = selected?.displayName.trim().isNotEmpty == true
        ? selected!.displayName
        : _deskHolderName;
    final pagePost = seats.isNotEmpty
        ? seats.map((p) => p.title).join(' · ')
        : _deskPostLabel;

    const radius = BorderRadius.only(
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );

    return Material(
      color: Colors.transparent,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: radius,
      child: InkWell(
        onTap: _pickMemberForDesk,
        borderRadius: radius,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFC2185B),
                Color(0xFFE91E63),
              ],
            ),
            borderRadius: radius,
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                child: Icon(Icons.people_outline, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Desk select',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      pageName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      pagePost,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.expand_more,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact desk selector (legacy — unused).
  // ignore: unused_element
  Widget _deskSelectorCard() {
    final mid = widget.memberId.trim();
    final selected = mid.isEmpty ? null : MemberStore.byId(mid);
    final seats = selected == null
        ? const <BoardPost>[]
        : BoardStore.postsForMember(selected.id);
    final seatHint = seats.isEmpty
        ? (selected == null ? 'Member select karein' : 'Member desk')
        : seats.map((p) => p.title).join(' · ');
    final name = selected?.displayName ?? 'Member select karein';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _pickMemberForDesk,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E2F2)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.purple.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.people_outline,
                  size: 18,
                  color: AppTheme.purple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Desk select',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      seatHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.expand_more, color: Colors.grey.shade700),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActionsCard() {
    const modules = [
      AppModule.members,
      AppModule.officers,
      AppModule.guests,
      AppModule.planner,
      AppModule.dashboard,
      AppModule.meetings,
      AppModule.accounts,
      AppModule.birthday,
      AppModule.activities,
      AppModule.gallery,
      AppModule.directory,
      AppModule.settings,
      AppModule.ai,
    ];
    final open = widget.onOpenModule;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Quick actions',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Modules yahan se kholo — Dashboard pe club wall hai',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in modules)
                  if (PostDeskAccess.openAllTemporarily ||
                      widget.role.modules.contains(m))
                    ActionChip(
                      avatar: Icon(m.icon, size: 18),
                      label: Text(m.title),
                      onPressed: open == null ? null : () => open(m),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMemberForDesk() async {
    final picked = await pickDeskPerson(
      context: context,
      currentMemberId: widget.memberId,
    );
    if (!mounted || picked == null) return;

    if (picked.memberId.trim().isNotEmpty &&
        (picked.scope == DeskPickScope.member ||
            picked.scope == DeskPickScope.board ||
            picked.scope == DeskPickScope.guest)) {
      final m = MemberStore.byId(picked.memberId);
      if (m != null) {
        if (picked.scope == DeskPickScope.board &&
            picked.boardPostId.trim().isNotEmpty) {
          final post = BoardStore.byId(picked.boardPostId);
          if (post != null) {
            await _switchToPost(post);
            return;
          }
        }
        await _switchToMember(m);
        return;
      }
    }

    // Guest / any club (no local member) — session by name.
    final name = picked.displayName.trim().isEmpty
        ? 'Guest'
        : picked.displayName.trim();
    final postTitle = picked.boardPostTitle.trim().isEmpty
        ? (picked.scope == DeskPickScope.anyClub ? 'Other club' : 'Guest')
        : picked.boardPostTitle.trim();
    await SessionService.login(
      name: name,
      role: ClubRole.member,
      memberId: picked.memberId.trim(),
      boardPostId: picked.boardPostId.trim(),
      boardPostTitle: postTitle,
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  BoardPost? get _currentPost {
    final id = widget.boardPostId.trim();
    if (id.isNotEmpty) {
      for (final p in BoardStore.current) {
        if (p.id == id) return p;
      }
    }
    final title = widget.boardPostTitle.trim();
    if (title.isNotEmpty) {
      for (final p in BoardStore.current) {
        if (p.title.trim().toLowerCase() == title.toLowerCase()) return p;
      }
    }
    return null;
  }

  /// Desk holder: Board pe assigned naam, warna "Member".
  String get _deskHolderName {
    final post = _currentPost;
    if (post != null) {
      final m = MemberStore.byId(post.memberId);
      final n = m?.displayName.trim() ?? '';
      return n.isEmpty ? 'Member' : n;
    }
    if (widget.boardPostTitle.trim().isEmpty &&
        widget.role == ClubRole.member) {
      final n = widget.userName.trim();
      return n.isEmpty ? 'Member' : n;
    }
    final m = MemberStore.byId(widget.memberId);
    final n = m?.displayName.trim() ?? '';
    return n.isEmpty ? 'Member' : n;
  }

  String get _deskPostLabel {
    final t = widget.boardPostTitle.trim();
    if (t.isNotEmpty) return t;
    return widget.role.label;
  }

  Widget _header(RoleDeskProfile profile) {
    final holder = _deskHolderName;
    final postLabel = _deskPostLabel;
    final assigned = _currentPost?.hasMember == true;
    // Purple AppBar se chipka — upar flat, neeche round.
    const radius = BorderRadius.only(
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );
    return Material(
      color: Colors.transparent,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: radius,
      child: InkWell(
        onTap: _pickMemberForDesk,
        borderRadius: radius,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFC2185B),
                Color(0xFFE91E63),
              ],
            ),
            borderRadius: radius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.headline,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$holder · $postLabel',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                assigned
                    ? 'Board post holder · personal desk'
                    : (widget.boardPostTitle.trim().isEmpty
                        ? 'Member desk'
                        : 'Board post vacant · Member desk'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _missionCard(RoleDeskProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_outlined, color: AppTheme.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                profile.mission,
                style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Text(
      t,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: AppTheme.ink,
      ),
    );
  }

  Widget _upcomingBlock() {
    if (_upcoming.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.event_available_outlined),
          title: const Text('Koi agami program nahi'),
          subtitle: const Text('Planner mein program add hone par yahan dikhega'),
          trailing: widget.onOpenModule == null
              ? null
              : TextButton(
                  onPressed: () => widget.onOpenModule!(AppModule.planner),
                  child: const Text('Planner'),
                ),
        ),
      );
    }
    return Column(
      children: _upcoming.map((p) {
        final when = p.dateTimeLabel;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.purple.withValues(alpha: 0.12),
              child: const Icon(Icons.event, color: AppTheme.purple),
            ),
            title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              [
                if (when.isNotEmpty) when,
                if (p.place.trim().isNotEmpty) p.place,
                if (p.hasPc) 'PC linked',
              ].join(' · '),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _accountsPreview() {
    final bal = AccountsStore.balance;
    final income = AccountsStore.totalIncome;
    final expense = AccountsStore.totalExpense;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Balance ₹${bal.toStringAsFixed(0)}  ·  Jama ₹${income.toStringAsFixed(0)}  ·  Kharch ₹${expense.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AccountsScreen()),
                    ).then((_) => _reload());
                  },
                  child: const Text('Poora Accounts ledger'),
                ),
                if (widget.onOpenModule != null)
                  TextButton(
                    onPressed: () => widget.onOpenModule!(AppModule.accounts),
                    child: const Text('Accounts module'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityBlock() {
    if (_activity.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Abhi koi desk draft save nahi'),
          subtitle: Text(
            'Jab koi post AI draft save karega, yahan dikhega',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
          ),
        ),
      );
    }
    return Column(
      children: _activity.take(6).map((d) {
        final preview = d.draftText.trim().replaceAll('\n', ' ');
        final short = preview.length > 90 ? '${preview.substring(0, 90)}…' : preview;
        return Card(
          child: ListTile(
            leading: Icon(d.desk.icon, color: AppTheme.purple),
            title: Text(d.desk.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              [
                if (d.programName.isNotEmpty) d.programName,
                short,
              ].where((e) => e.isNotEmpty).join(' — '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _switchToPost(BoardPost post) async {
    final role = BoardPostRoleMapper.roleForPost(post);
    await MemberStore.ensureLoaded();
    final holder = MemberStore.byId(post.memberId);
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
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  Future<void> _switchToMember(Member member) async {
    await MemberStore.ensureLoaded();
    await BoardStore.ensureLoaded();
    final seats = BoardStore.postsForMember(member.id);

    if (seats.length == 1) {
      await _switchToPost(seats.first);
      return;
    }

    if (seats.length > 1 && mounted) {
      final choice = await showDialog<Object>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text('${member.displayName} — post chunein'),
          children: [
            for (final p in seats)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, p),
                child: Text(p.title),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'member'),
              child: const Text('Sirf Member desk'),
            ),
          ],
        ),
      );
      if (!mounted || choice == null) return;
      if (choice is BoardPost) {
        await _switchToPost(choice);
        return;
      }
      // 'member' → plain member desk below
    }

    final name = member.displayName.trim().isEmpty
        ? 'Member'
        : member.displayName.trim();
    await SessionService.login(
      name: name,
      role: ClubRole.member,
      memberId: member.id,
      boardPostId: '',
      boardPostTitle: '',
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  Widget _toolTile(DeskType d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.purple.withValues(alpha: 0.12),
            child: Icon(d.icon, color: AppTheme.purple),
          ),
          title: Text(d.title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(d.subtitle),
          trailing: const Icon(Icons.auto_awesome, color: AppTheme.gold),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DeskWorkspaceScreen(
                  desk: d,
                  role: widget.role,
                  userName: widget.userName,
                ),
              ),
            ).then((_) => _reload());
          },
        ),
      ),
    );
  }
}

class DeskWorkspaceScreen extends StatefulWidget {
  const DeskWorkspaceScreen({
    super.key,
    required this.desk,
    required this.role,
    required this.userName,
  });

  final DeskType desk;
  final ClubRole role;
  final String userName;

  @override
  State<DeskWorkspaceScreen> createState() => _DeskWorkspaceScreenState();
}

class _DeskWorkspaceScreenState extends State<DeskWorkspaceScreen> {
  final _program = TextEditingController();
  final _date = TextEditingController();
  final _place = TextEditingController();
  final _guest = TextEditingController();
  final _draft = TextEditingController();
  String _lang = 'hi';
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await DeskDraftStore.load(widget.desk);
    if (saved != null) {
      _program.text = saved.programName;
      _date.text = saved.date;
      _place.text = saved.place;
      _guest.text = saved.guestOrNote;
      _draft.text = saved.draftText;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _program.dispose();
    _date.dispose();
    _place.dispose();
    _guest.dispose();
    _draft.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    final text = AiDraftService.generate(
      desk: widget.desk,
      role: widget.role,
      userName: widget.userName,
      programName: _program.text,
      date: _date.text,
      place: _place.text,
      guestOrNote: _guest.text,
      language: _lang,
    );
    setState(() {
      _draft.text = text;
      _busy = false;
    });
    await _persist();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI Assistant ne draft tayaar kiya')),
    );
  }

  Future<void> _persist() async {
    await DeskDraftStore.save(
      DeskDraft(
        desk: widget.desk,
        programName: _program.text.trim(),
        date: _date.text.trim(),
        place: _place.text.trim(),
        guestOrNote: _guest.text.trim(),
        draftText: _draft.text,
      ),
    );
  }

  Future<void> _save() async {
    await _persist();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft save ho gaya')),
    );
  }

  Future<void> _copy() async {
    if (_draft.text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _draft.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clipboard mein copy')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.desk;
    return Scaffold(
      appBar: AppBar(
        title: Text(d.title),
        actions: [
          IconButton(
            tooltip: 'Copy',
            onPressed: _copy,
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: 'Save',
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  d.subtitle,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Role: ${widget.role.label} · AI Assistant madad karega',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _program,
                  decoration: const InputDecoration(
                    labelText: 'Program / Meeting name',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _date,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    hintText: 'dd/MM/yyyy',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _place,
                  decoration: const InputDecoration(
                    labelText: 'Place',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _guest,
                  decoration: InputDecoration(
                    labelText: d == DeskType.birthdayWish || d == DeskType.anniversaryWish
                        ? 'Member / couple name'
                        : 'Chief guest / special note',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'hi', label: Text('हिंदी')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {_lang},
                  onSelectionChanged: (s) => setState(() => _lang = s.first),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _generate,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: const Text('AI Assistant se draft banao'),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Draft / Final text',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _draft,
                  maxLines: 16,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    alignLabelWithHint: true,
                    hintText: 'AI draft yahan aayega — aap edit kar sakte ho',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copy,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
