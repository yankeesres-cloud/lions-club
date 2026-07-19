import 'package:flutter/material.dart';

import 'screens/auth/role_login_screen.dart';
import 'screens/shell/main_shell.dart';
import 'services/board_store.dart';
import 'services/club_settings_store.dart';
import 'services/guest_store.dart';
import 'services/member_store.dart';
import 'services/planner_store.dart';
import 'services/session_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ClubSettingsStore.load();
  await MemberStore.load();
  await BoardStore.load();
  await GuestStore.load();
  await PlannerStore.load();
  final loggedIn = await SessionService.isLoggedIn();
  runApp(LionsClubProApp(loggedIn: loggedIn));
}

class LionsClubProApp extends StatelessWidget {
  const LionsClubProApp({super.key, required this.loggedIn});

  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lions Club Pro',
      theme: AppTheme.light,
      home: loggedIn ? const MainShell() : const RoleLoginScreen(),
    );
  }
}
