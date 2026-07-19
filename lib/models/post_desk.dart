import 'package:flutter/material.dart';

import 'club_role.dart';

/// Post-wise work pages — har officer apni field mein.
enum DeskType {
  agenda,
  abharSpeech,
  welcomeSpeech,
  invitation,
  meetingReport,
  birthdayWish,
  anniversaryWish,
  socialCaption,
  mediaRelease,
  accountsNote,
  serviceNote,
  noticeDraft,
}

extension DeskTypeX on DeskType {
  String get title {
    switch (this) {
      case DeskType.agenda:
        return 'Agenda';
      case DeskType.abharSpeech:
        return 'Abhar Speech';
      case DeskType.welcomeSpeech:
        return 'Welcome Speech';
      case DeskType.invitation:
        return 'Invitation';
      case DeskType.meetingReport:
        return 'Meeting Report';
      case DeskType.birthdayWish:
        return 'Birthday Wish';
      case DeskType.anniversaryWish:
        return 'Anniversary Wish';
      case DeskType.socialCaption:
        return 'Social Media Caption';
      case DeskType.mediaRelease:
        return 'Media Release';
      case DeskType.accountsNote:
        return 'Accounts Note';
      case DeskType.serviceNote:
        return 'Service Activity Note';
      case DeskType.noticeDraft:
        return 'Notice Draft';
    }
  }

  String get subtitle {
    switch (this) {
      case DeskType.agenda:
        return 'Meeting agenda points — Secretary field';
      case DeskType.abharSpeech:
        return 'Vote of thanks / Abhar bhashan';
      case DeskType.welcomeSpeech:
        return 'Swagat bhashan';
      case DeskType.invitation:
        return 'Program / meeting invitation text';
      case DeskType.meetingReport:
        return 'Meeting / program report';
      case DeskType.birthdayWish:
        return 'Member birthday message';
      case DeskType.anniversaryWish:
        return 'Anniversary wish';
      case DeskType.socialCaption:
        return 'Facebook / Instagram caption';
      case DeskType.mediaRelease:
        return 'Press / media note';
      case DeskType.accountsNote:
        return 'Fee / expense short note';
      case DeskType.serviceNote:
        return 'Service activity write-up';
      case DeskType.noticeDraft:
        return 'Club notice board draft';
    }
  }

  IconData get icon {
    switch (this) {
      case DeskType.agenda:
        return Icons.list_alt;
      case DeskType.abharSpeech:
        return Icons.volunteer_activism_outlined;
      case DeskType.welcomeSpeech:
        return Icons.waving_hand_outlined;
      case DeskType.invitation:
        return Icons.mail_outline;
      case DeskType.meetingReport:
        return Icons.description_outlined;
      case DeskType.birthdayWish:
        return Icons.cake_outlined;
      case DeskType.anniversaryWish:
        return Icons.favorite_border;
      case DeskType.socialCaption:
        return Icons.share_outlined;
      case DeskType.mediaRelease:
        return Icons.newspaper_outlined;
      case DeskType.accountsNote:
        return Icons.account_balance_wallet_outlined;
      case DeskType.serviceNote:
        return Icons.handshake_outlined;
      case DeskType.noticeDraft:
        return Icons.campaign_outlined;
    }
  }

  /// Hint fields shown in workspace.
  List<String> get fieldHints => const [
        'Program / meeting name',
        'Date',
        'Place',
        'Chief guest / special note',
      ];
}

class PostDeskAccess {
  /// TEMP: abhi sab desks / tools sabko open.
  ///
  /// Baad mein (permissions):
  /// 1) [openAllTemporarily] = false
  /// 2) Desk select Sirf Members list se rahega (board seats bhi unhi members se)
  /// 3) [desksFor] / modules role + board post ke hisaab se band
  static const bool openAllTemporarily = true;

  static bool roleSeesAll(ClubRole role) {
    if (openAllTemporarily) return true;
    return role == ClubRole.president || role == ClubRole.clubAdmin;
  }

  static Set<DeskType> desksFor(ClubRole role) {
    if (roleSeesAll(role) || openAllTemporarily) {
      return DeskType.values.toSet();
    }
    switch (role) {
      case ClubRole.secretary:
      case ClubRole.jointSecretary:
        return {
          DeskType.agenda,
          DeskType.meetingReport,
          DeskType.invitation,
          DeskType.noticeDraft,
          DeskType.abharSpeech,
        };
      case ClubRole.treasurer:
      case ClubRole.jointTreasurer:
        return {
          DeskType.accountsNote,
          DeskType.meetingReport,
        };
      case ClubRole.vp1:
      case ClubRole.vp2:
      case ClubRole.vp3:
        return {
          DeskType.welcomeSpeech,
          DeskType.abharSpeech,
          DeskType.invitation,
        };
      case ClubRole.pro:
      case ClubRole.mediaConvener:
      case ClubRole.marketingCommunication:
        return {
          DeskType.mediaRelease,
          DeskType.socialCaption,
          DeskType.invitation,
          DeskType.birthdayWish,
        };
      case ClubRole.serviceChair:
        return {
          DeskType.serviceNote,
          DeskType.invitation,
          DeskType.socialCaption,
        };
      case ClubRole.editor:
      case ClubRole.cmc:
        return {
          DeskType.mediaRelease,
          DeskType.socialCaption,
          DeskType.meetingReport,
          DeskType.noticeDraft,
        };
      case ClubRole.tailTwister:
        return {
          DeskType.welcomeSpeech,
          DeskType.socialCaption,
        };
      case ClubRole.boardMember:
        return {
          DeskType.abharSpeech,
          DeskType.welcomeSpeech,
          DeskType.birthdayWish,
        };
      case ClubRole.member:
        return {
          DeskType.birthdayWish,
          DeskType.anniversaryWish,
        };
      case ClubRole.president:
      case ClubRole.clubAdmin:
        return DeskType.values.toSet();
    }
  }
}
