import 'package:flutter/material.dart';

enum ClubRole {
  president,
  secretary,
  treasurer,
  vp1,
  vp2,
  vp3,
  jointSecretary,
  jointTreasurer,
  clubAdmin,
  marketingCommunication,
  serviceChair,
  pro,
  mediaConvener,
  tailTwister,
  cmc,
  editor,
  boardMember,
  member,
}

extension ClubRoleX on ClubRole {
  String get label {
    switch (this) {
      case ClubRole.president:
        return 'President';
      case ClubRole.secretary:
        return 'Secretary';
      case ClubRole.treasurer:
        return 'Treasurer';
      case ClubRole.vp1:
        return 'VP-1';
      case ClubRole.vp2:
        return 'VP-2';
      case ClubRole.vp3:
        return 'VP-3';
      case ClubRole.jointSecretary:
        return 'Joint Secretary';
      case ClubRole.jointTreasurer:
        return 'Joint Treasurer';
      case ClubRole.clubAdmin:
        return 'Club Administration';
      case ClubRole.marketingCommunication:
        return 'Club Marketing Communication';
      case ClubRole.serviceChair:
        return 'Club Service Chairperson';
      case ClubRole.pro:
        return 'PRO';
      case ClubRole.mediaConvener:
        return 'Media Convener';
      case ClubRole.tailTwister:
        return 'Tail Twister';
      case ClubRole.cmc:
        return 'CMC';
      case ClubRole.editor:
        return 'Editor';
      case ClubRole.boardMember:
        return 'Board Member';
      case ClubRole.member:
        return 'Member';
    }
  }

  /// Modules this role can open in V1 (expand later per officer duties).
  Set<AppModule> get modules {
    final all = AppModule.values.toSet();
    switch (this) {
      case ClubRole.president:
      case ClubRole.clubAdmin:
        // Adhyaksh / Admin — sab modules + sab post desks
        return all;
      case ClubRole.secretary:
      case ClubRole.jointSecretary:
        return {
          AppModule.dashboard,
          AppModule.members,
          AppModule.officers,
          AppModule.guests,
          AppModule.planner,
          AppModule.meetings,
          AppModule.gallery,
          AppModule.notices,
          AppModule.documents,
          AppModule.reports,
          AppModule.directory,
          AppModule.myDesk,
          AppModule.ai,
          AppModule.settings,
        };
      case ClubRole.treasurer:
      case ClubRole.jointTreasurer:
        return {
          AppModule.dashboard,
          AppModule.members,
          AppModule.officers,
          AppModule.guests,
          AppModule.planner,
          AppModule.accounts,
          AppModule.gallery,
          AppModule.reports,
          AppModule.directory,
          AppModule.documents,
          AppModule.myDesk,
          AppModule.ai,
          AppModule.settings,
        };
      case ClubRole.serviceChair:
        return {
          AppModule.dashboard,
          AppModule.planner,
          AppModule.activities,
          AppModule.gallery,
          AppModule.reports,
          AppModule.directory,
          AppModule.myDesk,
          AppModule.ai,
          AppModule.settings,
        };
      case ClubRole.member:
        return {
          AppModule.dashboard,
          AppModule.planner,
          AppModule.birthday,
          AppModule.meetings,
          AppModule.gallery,
          AppModule.notices,
          AppModule.directory,
          AppModule.myDesk,
          AppModule.ai,
          AppModule.settings,
        };
      default:
        return {
          AppModule.dashboard,
          AppModule.members,
          AppModule.officers,
          AppModule.guests,
          AppModule.planner,
          AppModule.meetings,
          AppModule.gallery,
          AppModule.notices,
          AppModule.directory,
          AppModule.reports,
          AppModule.myDesk,
          AppModule.ai,
          AppModule.settings,
        };
    }
  }

  bool get canEditClubSettings =>
      this == ClubRole.president ||
      this == ClubRole.secretary ||
      this == ClubRole.clubAdmin;
}

enum AppModule {
  dashboard,
  members,
  birthday,
  meetings,
  accounts,
  activities,
  gallery,
  notices,
  awards,
  documents,
  reports,
  directory,
  ai,
  myDesk,
  officers,
  guests,
  planner,
  settings,
}

extension AppModuleX on AppModule {
  String get title {
    switch (this) {
      case AppModule.dashboard:
        return 'Dashboard';
      case AppModule.members:
        return 'Members';
      case AppModule.birthday:
        return 'Birthday & Anniversary';
      case AppModule.meetings:
        return 'Meetings';
      case AppModule.accounts:
        return 'Accounts';
      case AppModule.activities:
        return 'Service Activities';
      case AppModule.gallery:
        return 'Photo Gallery';
      case AppModule.notices:
        return 'Notice Board';
      case AppModule.awards:
        return 'Awards & Honors';
      case AppModule.documents:
        return 'Documents';
      case AppModule.reports:
        return 'Reports';
      case AppModule.directory:
        return 'Anya Club Members';
      case AppModule.ai:
        return 'AI Assistant';
      case AppModule.myDesk:
        return 'Mera Desk';
      case AppModule.officers:
        return 'Board Members';
      case AppModule.guests:
        return 'Guest List';
      case AppModule.planner:
        return 'Planner';
      case AppModule.settings:
        return 'Settings';
    }
  }

  IconData get icon {
    switch (this) {
      case AppModule.dashboard:
        return Icons.dashboard_outlined;
      case AppModule.members:
        return Icons.groups_outlined;
      case AppModule.birthday:
        return Icons.cake_outlined;
      case AppModule.meetings:
        return Icons.event_outlined;
      case AppModule.accounts:
        return Icons.account_balance_wallet_outlined;
      case AppModule.activities:
        return Icons.volunteer_activism_outlined;
      case AppModule.gallery:
        return Icons.photo_library_outlined;
      case AppModule.notices:
        return Icons.campaign_outlined;
      case AppModule.awards:
        return Icons.emoji_events_outlined;
      case AppModule.documents:
        return Icons.folder_outlined;
      case AppModule.reports:
        return Icons.bar_chart_outlined;
      case AppModule.directory:
        return Icons.contact_phone_outlined;
      case AppModule.ai:
        return Icons.auto_awesome_outlined;
      case AppModule.myDesk:
        return Icons.desk_outlined;
      case AppModule.officers:
        return Icons.badge_outlined;
      case AppModule.guests:
        return Icons.diversity_3_outlined;
      case AppModule.planner:
        return Icons.event_note_outlined;
      case AppModule.settings:
        return Icons.settings_outlined;
    }
  }
}
