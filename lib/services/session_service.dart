import 'package:shared_preferences/shared_preferences.dart';

import '../models/club_role.dart';

/// V1 local session. Later: cloud + per-club multi-tenant.
class SessionService {
  static const _kLoggedIn = 'lions_logged_in';
  static const _kRole = 'lions_role';
  static const _kName = 'lions_user_name';
  static const _kMemberId = 'lions_member_id';
  static const _kBoardPostId = 'lions_board_post_id';
  static const _kBoardPostTitle = 'lions_board_post_title';

  static Future<bool> isLoggedIn() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kLoggedIn) ?? false;
  }

  static Future<ClubRole> currentRole() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kRole) ?? ClubRole.member.name;
    return ClubRole.values.firstWhere(
      (r) => r.name == raw,
      orElse: () => ClubRole.member,
    );
  }

  static Future<String> currentName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kName) ?? 'Member';
  }

  static Future<String> currentMemberId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kMemberId) ?? '';
  }

  static Future<String> currentBoardPostId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kBoardPostId) ?? '';
  }

  static Future<String> currentBoardPostTitle() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kBoardPostTitle) ?? '';
  }

  static Future<void> login({
    required String name,
    required ClubRole role,
    String memberId = '',
    String boardPostId = '',
    String boardPostTitle = '',
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLoggedIn, true);
    await p.setString(_kRole, role.name);
    await p.setString(_kName, name.trim().isEmpty ? role.label : name.trim());
    await p.setString(_kMemberId, memberId.trim());
    await p.setString(_kBoardPostId, boardPostId.trim());
    await p.setString(_kBoardPostTitle, boardPostTitle.trim());
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLoggedIn, false);
    await p.remove(_kMemberId);
    await p.remove(_kBoardPostId);
    await p.remove(_kBoardPostTitle);
  }
}
