import 'club_role.dart';
import 'post_desk.dart';

/// Har post / login ka alag desk profile — info + quick links.
class RoleDeskProfile {
  const RoleDeskProfile({
    required this.role,
    required this.headline,
    required this.mission,
    required this.infoBullets,
    required this.quickModuleHints,
  });

  final ClubRole role;
  final String headline;
  final String mission;
  final List<String> infoBullets;
  /// Module titles to highlight on desk (user UI chips).
  final List<AppModule> quickModuleHints;

  RoleDeskProfile withHeadline(String h) => RoleDeskProfile(
        role: role,
        headline: h,
        mission: mission,
        infoBullets: infoBullets,
        quickModuleHints: quickModuleHints,
      );

  /// [boardPostTitle] Board Members se assign post — desk naam usi se.
  static RoleDeskProfile forRole(ClubRole role, {String boardPostTitle = ''}) {
    final base = _baseForRole(role);
    if (boardPostTitle.trim().isEmpty) return base;
    return base.withHeadline('${boardPostTitle.trim()} Desk');
  }

  static RoleDeskProfile _baseForRole(ClubRole role) {
    switch (role) {
      case ClubRole.president:
        return RoleDeskProfile(
          role: role,
          headline: 'Adhyaksh Desk',
          mission: 'Poora club overview — har post ka kaam yahan se dekh sakte ho.',
          infoBullets: const [
            'Board, Guests, Planner, Accounts sab open',
            'Har officer ke desk tools review kar sakte ho',
            'AI se speech / notice / report draft',
            'Agami programs + reminders monitor',
          ],
          quickModuleHints: const [
            AppModule.officers,
            AppModule.planner,
            AppModule.guests,
            AppModule.accounts,
            AppModule.members,
          ],
        );
      case ClubRole.clubAdmin:
        return RoleDeskProfile(
          role: role,
          headline: 'Club Administration Desk',
          mission: 'Club settings, records aur sab desks manage.',
          infoBullets: const [
            'Club settings edit',
            'Members / Board / Guests maintain',
            'Sab AI desks available',
          ],
          quickModuleHints: const [
            AppModule.settings,
            AppModule.members,
            AppModule.officers,
            AppModule.planner,
          ],
        );
      case ClubRole.secretary:
      case ClubRole.jointSecretary:
        return RoleDeskProfile(
          role: role,
          headline: 'Secretary Desk',
          mission: 'Agenda, notice, meeting report — aapka field.',
          infoBullets: const [
            'Agenda draft (AI)',
            'Notice / invitation',
            'Meeting report',
            'Abhar speech support',
            'Agami programs Planner se',
          ],
          quickModuleHints: const [
            AppModule.planner,
            AppModule.meetings,
            AppModule.notices,
            AppModule.members,
          ],
        );
      case ClubRole.treasurer:
      case ClubRole.jointTreasurer:
        return RoleDeskProfile(
          role: role,
          headline: 'Treasurer Desk — Accounts',
          mission: 'Income, expense, pending — accounts yahan.',
          infoBullets: const [
            'Accounts ledger (jama / kharch)',
            'Accounts note AI draft',
            'Members fee related notes',
            'Program budget checklist Planner se',
          ],
          quickModuleHints: const [
            AppModule.accounts,
            AppModule.members,
            AppModule.planner,
            AppModule.reports,
          ],
        );
      case ClubRole.vp1:
      case ClubRole.vp2:
      case ClubRole.vp3:
        return RoleDeskProfile(
          role: role,
          headline: '${role.label} Desk',
          mission: 'Welcome / Abhar speech aur program support.',
          infoBullets: const [
            'Welcome speech AI',
            'Abhar speech AI',
            'Invitation draft',
            'Agami programs dekho',
          ],
          quickModuleHints: const [AppModule.planner, AppModule.guests],
        );
      case ClubRole.pro:
      case ClubRole.mediaConvener:
      case ClubRole.marketingCommunication:
        return RoleDeskProfile(
          role: role,
          headline: '${role.label} Desk',
          mission: 'Media, social caption, invitation — aapki field.',
          infoBullets: const [
            'Media release AI',
            'Social caption AI',
            'Birthday wishes',
            'Purane program photos',
          ],
          quickModuleHints: const [
            AppModule.gallery,
            AppModule.planner,
            AppModule.notices,
          ],
        );
      case ClubRole.serviceChair:
        return RoleDeskProfile(
          role: role,
          headline: 'Service Chair Desk',
          mission: 'Service activities, reports aur photos.',
          infoBullets: const [
            'Service note AI',
            'Planner programs',
            'Activity photos',
            'Invitation for camps',
          ],
          quickModuleHints: const [
            AppModule.activities,
            AppModule.planner,
            AppModule.gallery,
          ],
        );
      case ClubRole.editor:
      case ClubRole.cmc:
        return RoleDeskProfile(
          role: role,
          headline: '${role.label} Desk',
          mission: 'Content, media, reports.',
          infoBullets: const [
            'Media release / caption',
            'Meeting report polish',
            'Notice draft',
            'Gallery photos',
          ],
          quickModuleHints: const [
            AppModule.gallery,
            AppModule.notices,
            AppModule.planner,
          ],
        );
      case ClubRole.tailTwister:
        return RoleDeskProfile(
          role: role,
          headline: 'Tail Twister Desk',
          mission: 'Fun, welcome energy, social posts.',
          infoBullets: const [
            'Welcome speech light tone',
            'Social captions',
            'Agami programs',
          ],
          quickModuleHints: const [AppModule.planner, AppModule.gallery],
        );
      case ClubRole.boardMember:
        return RoleDeskProfile(
          role: role,
          headline: 'Board Member Desk',
          mission: 'Board support — speech aur wishes.',
          infoBullets: const [
            'Welcome / Abhar speech',
            'Birthday wishes',
            'Agami programs',
            'Board list',
          ],
          quickModuleHints: const [
            AppModule.officers,
            AppModule.planner,
            AppModule.gallery,
          ],
        );
      case ClubRole.member:
        return RoleDeskProfile(
          role: role,
          headline: 'Member Desk',
          mission: 'Agami programmes, purani photos, club updates.',
          infoBullets: const [
            'Agami programmes (Planner)',
            'Pehle programmes ke photos',
            'Anya members / board ka kaam overview',
            'Birthday / anniversary wish AI',
          ],
          quickModuleHints: const [
            AppModule.planner,
            AppModule.gallery,
            AppModule.birthday,
            AppModule.directory,
          ],
        );
    }
  }

  List<DeskType> get tools => PostDeskAccess.desksFor(role).toList()
    ..sort((a, b) => a.title.compareTo(b.title));
}
