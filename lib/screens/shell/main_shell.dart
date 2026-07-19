import 'package:flutter/material.dart';

import '../../models/club_role.dart';
import '../../models/member.dart';
import '../../models/post_desk.dart';
import '../../services/club_settings_store.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/module_scaffold.dart';
import '../auth/role_login_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../members/members_screen.dart';
import '../desk/post_desk_hub_screen.dart';
import '../guests/guest_list_screen.dart';
import '../officers/board_members_screen.dart';
import '../planner/planner_screen.dart';
import '../accounts/accounts_screen.dart';
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
      AppModule.myDesk,
      AppModule.accounts,
      AppModule.gallery,
      AppModule.directory,
      AppModule.meetings,
      AppModule.birthday,
    ];
    final set = _role.modules;
    final ordered = <AppModule>[
      for (final m in priority)
        if (set.contains(m)) m,
      for (final m in AppModule.values)
        if (set.contains(m) && !priority.contains(m)) m,
    ];
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final wide = MediaQuery.sizeOf(context).width >= 960;
    final allowed = _allowed;

    late final Widget body;
    if (_module == AppModule.dashboard) {
      body = DashboardScreen(
        role: _role,
        userName: _name,
        club: _club,
        onOpenModule: (m) => setState(() => _module = m),
      );
    } else if (_module == AppModule.members) {
      body = MembersScreen(role: _role);
    } else if (_module == AppModule.officers) {
      body = BoardMembersScreen(role: _role);
    } else if (_module == AppModule.guests) {
      body = GuestListScreen(role: _role);
    } else if (_module == AppModule.planner) {
      body = PlannerScreen(role: _role);
    } else if (_module == AppModule.myDesk || _module == AppModule.ai) {
      body = PostDeskHubScreen(
        role: _role,
        userName: _name,
        memberId: _memberId,
        boardPostId: _boardPostId,
        boardPostTitle: _boardPostTitle,
        onOpenModule: (m) {
          // TEMP: Mera Desk se sab modules open (baad mein permission)
          if (PostDeskAccess.openAllTemporarily || _role.modules.contains(m)) {
            setState(() => _module = m);
          }
        },
      );
    } else if (_module == AppModule.accounts) {
      body = const AccountsScreen();
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
                final i = allowed.indexOf(_module);
                return i < 0 ? 0 : i;
              }(),
              onDestinationSelected: (i) => setState(() => _module = allowed[i]),
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
                  title: Text(
                    _module == AppModule.dashboard ? _club.clubName : _module.title,
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Center(
                        child: Text(_role.label, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: () => setState(() => _module = AppModule.settings),
                      icon: const Icon(Icons.settings),
                    ),
                    IconButton(
                      tooltip: 'Logout',
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

    final bottomMods = allowed.take(4).toList();
    final bottomIndex =
        bottomMods.contains(_module) ? bottomMods.indexOf(_module) : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_module == AppModule.dashboard ? _club.clubName : _module.title),
        actions: [
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
                    '$_name · ${_role.label}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
            for (final m in allowed)
              ListTile(
                leading: Icon(m.icon),
                title: Text(m.title),
                selected: m == _module,
                onTap: () {
                  setState(() => _module = m);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: bottomIndex,
        onDestinationSelected: (i) => setState(() => _module = bottomMods[i]),
        destinations: [
          for (final m in bottomMods)
            NavigationDestination(
              icon: Icon(m.icon),
              label: m.title.split(' ').first,
            ),
        ],
      ),
    );
  }
}
