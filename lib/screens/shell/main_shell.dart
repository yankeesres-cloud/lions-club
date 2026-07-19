import 'package:flutter/material.dart';

import '../../models/board_post.dart';
import '../../models/board_post_role_mapper.dart';
import '../../models/club_role.dart';
import '../../models/member.dart';
import '../../models/post_desk.dart';
import '../../services/board_store.dart';
import '../../services/club_settings_store.dart';
import '../../services/member_store.dart';
import '../../services/member_usage_store.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/board_notice_box.dart';
import '../../widgets/desk_select_dialog.dart';
import '../../widgets/module_scaffold.dart';
import '../auth/role_login_screen.dart';
import '../members/members_screen.dart';
import '../desk/post_desk_hub_screen.dart';
import '../guests/guest_list_screen.dart';
import '../officers/board_members_screen.dart';
import '../planner/planner_screen.dart';
import '../accounts/accounts_screen.dart';
import '../accounts/treasurer_work_screen.dart';
import '../gallery/gallery_screen.dart';
import '../directory/club_directory_screen.dart';
import '../settings/club_settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  ClubRole _role = ClubRole.member;
  String _name = 'Member';
  String _memberId = '';
  String _boardPostTitle = '';
  String _boardPostId = '';
  ClubProfile _club = const ClubProfile();
  AppModule _module = AppModule.myDesk;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final role = await SessionService.currentRole();
    final name = await SessionService.currentName();
    final memberId = await SessionService.currentMemberId();
    final boardPostTitle = await SessionService.currentBoardPostTitle();
    final boardPostId = await SessionService.currentBoardPostId();
    final club = await ClubSettingsStore.load();
    await MemberStore.ensureLoaded();
    await BoardStore.ensureLoaded();
    await MemberUsageStore.recordOpen(memberId);
    if (!mounted) return;
    setState(() {
      _role = role;
      _name = name;
      _memberId = memberId;
      _boardPostTitle = boardPostTitle;
      _boardPostId = boardPostId;
      _club = club;
      _loading = false;
      if (!_role.modules.contains(_module)) {
        _module = _role.modules.contains(AppModule.myDesk)
            ? AppModule.myDesk
            : AppModule.dashboard;
      }
    });
  }

  /// Select ke baad AppBar pe sirf: Naam + Post.
  String get _deskName {
    final m = MemberStore.byId(_memberId);
    final n = m?.displayName.trim() ?? '';
    if (n.isNotEmpty) return n;
    return _name.trim().isEmpty ? 'Member' : _name.trim();
  }

  String get _deskPost {
    final t = _boardPostTitle.trim();
    if (t.isNotEmpty) return t;
    final mid = _memberId.trim();
    if (mid.isNotEmpty) {
      final seats = BoardStore.postsForMember(mid);
      if (seats.isNotEmpty) {
        return seats.map((p) => p.title).join(' · ');
      }
    }
    return _role.label;
  }

  String get _clubTitle {
    final n = _club.clubName.trim();
    return n.isEmpty ? 'Lions Club Gwalior Maitri' : n;
  }

  String get _appBarTitle {
    if (_module == AppModule.myDesk ||
        _module == AppModule.ai ||
        _module == AppModule.dashboard) {
      return '$_deskName · $_deskPost';
    }
    return _module.title;
  }

  bool get _isTreasurerDesk {
    if (_role == ClubRole.treasurer || _role == ClubRole.jointTreasurer) {
      return true;
    }
    final t = _boardPostTitle.toUpperCase();
    return t.contains('TREASURER') || t.contains('कोषाध्यक्ष');
  }

  DateTime? _appBarTapAt;
  int _appBarTapCount = 0;

  /// Purple title taps — Flutter onTap+onDoubleTap conflict avoid (manual).
  /// 1 tap: Treasurer → expenses · baaki → desk select
  /// 2 tap: board message (sabke liye)
  void _onPurpleTitleTap() {
    final now = DateTime.now();
    if (_appBarTapAt != null &&
        now.difference(_appBarTapAt!) < const Duration(milliseconds: 320)) {
      _appBarTapCount++;
    } else {
      _appBarTapCount = 1;
    }
    _appBarTapAt = now;
    final n = _appBarTapCount;
    Future<void>.delayed(const Duration(milliseconds: 330), () {
      if (!mounted || _appBarTapCount != n) return;
      if (n >= 2) {
        _appBarTapCount = 0;
        _composeBoardNotice();
        return;
      }
      _appBarTapCount = 0;
      if (_isTreasurerDesk) {
        setState(() => _module = AppModule.accounts);
      } else {
        _pickDeskFromMenu();
      }
    });
  }

  /// Desk AppBar: club + naam + post — 3 line (purple).
  Widget _deskAppBarTitle() {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onPurpleTitleTap,
          onLongPress: _pickDeskFromMenu,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _clubTitle.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _deskName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _deskPost,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _deskAppBarActions() {
    return [
      if (_isTreasurerDesk)
        IconButton(
          tooltip: 'Treasurer expenses',
          onPressed: () => setState(() => _module = AppModule.accounts),
          icon: const Icon(Icons.account_balance_wallet_outlined),
        ),
      IconButton(
        tooltip: 'Board message (2 tap jaisa)',
        onPressed: _composeBoardNotice,
        icon: const Icon(Icons.campaign_outlined),
      ),
      IconButton(
        tooltip: 'Desk select',
        onPressed: _pickDeskFromMenu,
        icon: const Icon(Icons.swap_horiz),
      ),
      IconButton(
        tooltip: 'Settings',
        onPressed: () => setState(() => _module = AppModule.settings),
        icon: const Icon(Icons.settings),
      ),
      IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
    ];
  }

  Future<void> _composeBoardNotice() async {
    // Post title empty ho to composer BoardStore se usi member ki post use karta hai.
    var postTitle = _boardPostTitle.trim();
    if (postTitle.isEmpty) {
      final seats = BoardStore.postsForMember(_memberId);
      if (seats.isNotEmpty) postTitle = seats.first.title.trim();
    }
    await openBoardNoticeComposer(
      context: context,
      userName: _deskName,
      memberId: _memberId,
      boardPostTitle: postTitle,
    );
  }

  Future<void> _pickDeskFromMenu() async {
    final picked = await pickDeskPerson(
      context: context,
      currentMemberId: _memberId,
    );
    if (!mounted || picked == null) return;

    var postId = picked.boardPostId.trim();
    var postTitle = picked.boardPostTitle.trim();
    final memberId = picked.memberId.trim();
    final name = picked.displayName.trim().isEmpty
        ? 'Member'
        : picked.displayName.trim();

    // Board: multiple posts → choose seat.
    if (picked.scope == DeskPickScope.board &&
        memberId.isNotEmpty &&
        postId.isEmpty) {
      final seats = BoardStore.postsForMember(memberId);
      if (seats.length == 1) {
        postId = seats.first.id;
        postTitle = seats.first.title;
      } else if (seats.length > 1) {
        final choice = await showDialog<Object>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text('$name — post chunein'),
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
          postId = choice.id;
          postTitle = choice.title;
        } else {
          postTitle = 'Member';
        }
      }
    }

    if (postTitle.isEmpty) {
      postTitle = switch (picked.scope) {
        DeskPickScope.member => 'Member',
        DeskPickScope.board => 'Board',
        DeskPickScope.guest => 'Guest',
        DeskPickScope.anyClub => 'Other club',
      };
    }

    // Board post se role; warna pehla role rakho — Members drawer se hat na jaye.
    var role = _role;
    if (picked.scope == DeskPickScope.board && postTitle.isNotEmpty) {
      role = BoardPostRoleMapper.roleForTitle(postTitle);
    } else if (picked.scope == DeskPickScope.member ||
        picked.scope == DeskPickScope.guest ||
        picked.scope == DeskPickScope.anyClub) {
      if (role == ClubRole.member) {
        role = ClubRole.boardMember; // modules mein Members/Guests shamil
      }
    }

    await SessionService.login(
      name: name,
      role: role,
      memberId: memberId,
      boardPostId: postId,
      boardPostTitle: postTitle,
    );
    if (!mounted) return;
    setState(() {
      _name = name;
      _memberId = memberId;
      _boardPostId = postId;
      _boardPostTitle = postTitle;
      _role = role;
      _module = AppModule.myDesk;
    });
  }

  Future<void> _logout() async {
    await SessionService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RoleLoginScreen()),
    );
  }

  List<AppModule> get _allowed {
    const priority = [
      AppModule.dashboard,
      AppModule.members,
      AppModule.officers,
      AppModule.guests,
      AppModule.planner,
      AppModule.accounts,
      AppModule.gallery,
      AppModule.directory,
      AppModule.meetings,
      AppModule.birthday,
    ];
    // Pilot: sab modules drawer mein (desk select role change se Members hide na ho).
    final set = PostDeskAccess.openAllTemporarily
        ? AppModule.values.toSet()
        : _role.modules;
    final ordered = <AppModule>[
      for (final m in priority)
        if (set.contains(m)) m,
      for (final m in AppModule.values)
        if (set.contains(m) &&
            !priority.contains(m) &&
            m != AppModule.myDesk &&
            m != AppModule.ai)
          m,
    ];
    // Dashboard pehle — Mera Desk open karta hai; alag Mera Desk entry nahi.
    return ordered;
  }

  void _openModule(AppModule m) {
    MemberUsageStore.recordOpen(_memberId);
    // Pehla option Dashboard = Mera Desk.
    if (m == AppModule.dashboard) {
      setState(() => _module = AppModule.myDesk);
      return;
    }
    setState(() => _module = m);
  }

  bool get _onDesk =>
      _module == AppModule.myDesk ||
      _module == AppModule.ai ||
      _module == AppModule.dashboard;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final wide = MediaQuery.sizeOf(context).width >= 960;
    final allowed = _allowed;

    late final Widget body;
    if (_module == AppModule.dashboard ||
        _module == AppModule.myDesk ||
        _module == AppModule.ai) {
      body = PostDeskHubScreen(
        role: _role,
        userName: _name,
        memberId: _memberId,
        boardPostId: _boardPostId,
        boardPostTitle: _boardPostTitle,
        onOpenModule: (m) {
          if (PostDeskAccess.openAllTemporarily || _role.modules.contains(m)) {
            _openModule(m);
          }
        },
      );
    } else if (_module == AppModule.members) {
      body = MembersScreen(role: _role);
    } else if (_module == AppModule.officers) {
      body = BoardMembersScreen(role: _role);
    } else if (_module == AppModule.guests) {
      body = GuestListScreen(role: _role);
    } else if (_module == AppModule.planner) {
      body = PlannerScreen(role: _role);
    } else if (_module == AppModule.accounts) {
      body = _isTreasurerDesk
          ? const TreasurerWorkScreen()
          : const AccountsScreen(canEdit: false);
    } else if (_module == AppModule.gallery) {
      body = const GalleryScreen();
    } else if (_module == AppModule.directory) {
      body = ClubDirectoryScreen(role: _role);
    } else if (_module == AppModule.settings) {
      body = ClubSettingsScreen(
        role: _role,
        onSaved: () async {
          final club = await ClubSettingsStore.load();
          if (!mounted) return;
          setState(() => _club = club);
        },
        onLogout: _logout,
      );
    } else {
      body = ModuleHubPage(module: _module);
    }

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1180,
              backgroundColor: Colors.white,
              selectedIndex: () {
                final current =
                    (_module == AppModule.myDesk || _module == AppModule.ai)
                        ? AppModule.dashboard
                        : _module;
                final i = allowed.indexOf(current);
                return i < 0 ? 0 : i;
              }(),
              onDestinationSelected: (i) => _openModule(allowed[i]),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    const Icon(Icons.pets, color: AppTheme.purple, size: 28),
                    const SizedBox(height: 4),
                    Text(
                      'Lions',
                      style: TextStyle(
                        color: AppTheme.purpleDeep,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              destinations: [
                for (final m in allowed)
                  NavigationRailDestination(
                    icon: Icon(m.icon),
                    label: Text(m.title),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Scaffold(
                appBar: AppBar(
                  toolbarHeight: _onDesk ? 72 : kToolbarHeight,
                  title: _onDesk ? _deskAppBarTitle() : Text(_appBarTitle),
                  actions: _onDesk
                      ? _deskAppBarActions()
                      : [
                          IconButton(
                            tooltip: 'Settings',
                            onPressed: () =>
                                setState(() => _module = AppModule.settings),
                            icon: const Icon(Icons.settings),
                          ),
                          IconButton(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout),
                          ),
                        ],
                ),
                body: body,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: _onDesk ? 72 : kToolbarHeight,
        title: _onDesk ? _deskAppBarTitle() : Text(_appBarTitle),
        actions: _onDesk
            ? _deskAppBarActions()
            : [
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => setState(() => _module = AppModule.settings),
                  icon: const Icon(Icons.settings),
                ),
                IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
              ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.purple),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.pets, color: AppTheme.goldSoft, size: 36),
                  const Spacer(),
                  Text(
                    _club.clubName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$_deskName · $_deskPost',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Desk select'),
              subtitle: Text('$_deskName · $_deskPost'),
              onTap: () {
                Navigator.pop(context);
                _pickDeskFromMenu();
              },
            ),
            const Divider(),
            for (final m in allowed)
              ListTile(
                leading: Icon(m.icon),
                title: Text(m.title),
                selected: m == AppModule.dashboard
                    ? (_module == AppModule.dashboard ||
                        _module == AppModule.myDesk ||
                        _module == AppModule.ai)
                    : m == _module,
                onTap: () {
                  _openModule(m);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
      body: body,
    );
  }
}
