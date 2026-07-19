import 'package:shared_preferences/shared_preferences.dart';

import 'ai_draft_service.dart';
import 'app_clock.dart';
import 'board_store.dart';
import 'club_chat_store.dart';
import 'club_settings_store.dart';
import 'member_store.dart';

/// Aaj + kal ke birthday / anniversary par AI wish club wall pe auto post.
class OccasionWallPoster {
  static const _kPosted = 'lions_occasion_wall_posted_v2';
  static const _senderId = 'system_ai';

  static Future<void> clearPostedHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPosted);
    await prefs.remove('lions_occasion_wall_posted_v1');
  }

  /// Desk / wall open hone par — aaj aur kal; pehle se post ho to skip.
  static Future<int> postTodaysWishes() async {
    await Future.wait([
      MemberStore.ensureLoaded(),
      ClubChatStore.ensureLoaded(),
      ClubSettingsStore.ensureLoaded(),
      BoardStore.ensureLoaded(),
    ]);

    final today = AppClock.today;

    final prefs = await SharedPreferences.getInstance();
    final posted = (prefs.getStringList(_kPosted) ?? []).toSet();

    final members = MemberStore.current;
    final club = ClubSettingsStore.current.clubName.trim();
    final sender = club.isEmpty ? 'Club AI' : '$club · AI';

    var count = 0;

    // 0 = aaj, 1 = kal
    for (final offset in [0, 1]) {
      final day = today.add(Duration(days: offset));
      final dayKey = '${day.year}_${day.month}_${day.day}';
      final forTomorrow = offset == 1;
      final seenAnn = <String>{};

      for (final m in members) {
        final name = m.displayName.trim();
        if (name.isEmpty) continue;

        if (m.hasBirthdayOn(day)) {
          final id = 'bday_${dayKey}_${m.id}';
          if (!posted.contains(id)) {
            await ClubChatStore.send(
              senderName: sender,
              senderMemberId: _senderId,
              text: AiDraftService.birthdayWallWishForMember(
                m,
                forTomorrow: forTomorrow,
              ),
            );
            posted.add(id);
            count++;
          }
        }

        if (m.hasAnniversaryOn(day)) {
          final annKey = m.anniversary.trim();
          if (annKey.isEmpty || seenAnn.contains(annKey)) continue;
          seenAnn.add(annKey);

          final mates = members
              .where(
                (o) =>
                    o.anniversary.trim() == annKey &&
                    o.hasAnniversaryOn(day),
              )
              .toList();
          final id = 'ann_${dayKey}_${annKey.hashCode}';
          if (!posted.contains(id)) {
            await ClubChatStore.send(
              senderName: sender,
              senderMemberId: _senderId,
              text: AiDraftService.anniversaryWallWishForMembers(
                mates.isEmpty ? [m] : mates,
                forTomorrow: forTomorrow,
              ),
            );
            posted.add(id);
            count++;
          }
        }
      }
    }

    final pruned = posted.where((k) => _isRecentKey(k, today)).toList();
    await prefs.setStringList(_kPosted, pruned);
    return count;
  }

  static bool _isRecentKey(String key, DateTime today) {
    final m = RegExp(r'^(?:bday|ann)_(\d+)_(\d+)_(\d+)_').firstMatch(key);
    if (m == null) return false;
    final y = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final d = int.tryParse(m.group(3)!);
    if (y == null || mo == null || d == null) return false;
    try {
      final when = DateTime(y, mo, d);
      return today.difference(when).inDays.abs() <= 40;
    } catch (_) {
      return false;
    }
  }
}
