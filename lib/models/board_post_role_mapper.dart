import 'board_post.dart';
import 'club_role.dart';

/// Board post title → app [ClubRole] (desk + modules).
class BoardPostRoleMapper {
  static ClubRole roleForTitle(String title) {
    final t = title.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

    if (t.contains('JOINT') && t.contains('SECRETARY')) {
      return ClubRole.jointSecretary;
    }
    if (t.contains('JOINT') && t.contains('TREASURER')) {
      return ClubRole.jointTreasurer;
    }
    if (t == 'PRESIDENT' || t.startsWith('PRESIDENT ')) {
      return ClubRole.president;
    }
    if (t.contains('SECRETARY')) return ClubRole.secretary;
    if (t.contains('TREASURER')) return ClubRole.treasurer;

    final vpLevel = vpLevelFromTitle(t);
    if (vpLevel == 1) return ClubRole.vp1;
    if (vpLevel == 2) return ClubRole.vp2;
    if (vpLevel == 3) return ClubRole.vp3;

    if (t.contains('ADMINISTRATION') || t.contains('CLUB ADMIN')) {
      return ClubRole.clubAdmin;
    }
    if (t.contains('MARKETING') && t.contains('COMMUNICATION')) {
      return ClubRole.marketingCommunication;
    }
    if (t.contains('SERVICE') && (t.contains('CHAIR') || t.contains('CHAIRPERSON'))) {
      return ClubRole.serviceChair;
    }
    if (t == 'PRO' || t.startsWith('PRO ') || t.endsWith(' PRO')) {
      return ClubRole.pro;
    }
    if (t.contains('MEDIA')) return ClubRole.mediaConvener;
    if (t.contains('TAIL') && t.contains('TWISTER')) {
      return ClubRole.tailTwister;
    }
    if (t == 'CMC' || t.contains('CMC')) return ClubRole.cmc;
    if (t.contains('EDITOR')) return ClubRole.editor;

    // Founder, IPP, Directors, LICF, Tamor, Greeting, etc.
    return ClubRole.boardMember;
  }

  static ClubRole roleForPost(BoardPost post) => roleForTitle(post.title);

  /// Board title → VP level 1/2/3, warna 0.
  /// Accepts: V.P.-1, V.P. -1, VP 1, VP-2, 1ST VICE PRESIDENT, …
  static int vpLevelFromTitle(String title) {
    final t = title.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return 0;
    // Prefer explicit 1/2/3 near VP / VICE PRESIDENT
    for (final n in [1, 2, 3]) {
      final ns = '$n';
      if (RegExp(
        r'(?:^|[^A-Z0-9])(?:V\.?\s*P\.?|VP|VICE\s*PRESIDENT)\s*[.\-]?\s*' +
            ns +
            r'(?:[^0-9]|$)',
      ).hasMatch(t)) {
        return n;
      }
      if (RegExp(
        r'(?:^|[^A-Z0-9])' +
            ns +
            r'(?:ST|ND|RD|TH)?\s*(?:V\.?\s*P\.?|VP|VICE\s*PRESIDENT)',
      ).hasMatch(t)) {
        return n;
      }
    }
    if (t.contains('V.P.-1') || t.contains('VP-1') || t.contains('VP 1')) {
      return 1;
    }
    if (t.contains('V.P.-2') || t.contains('VP-2') || t.contains('VP 2')) {
      return 2;
    }
    if (t.contains('V.P.-3') || t.contains('VP-3') || t.contains('VP 3')) {
      return 3;
    }
    return 0;
  }

  static String deskHeadline(BoardPost? post, ClubRole role) {
    if (post != null && post.title.trim().isNotEmpty) {
      return '${_titleCase(post.title)} Desk';
    }
    return '${role.label} Desk';
  }

  static String _titleCase(String raw) {
    return raw
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) {
          if (w.length <= 3 && w == w.toUpperCase()) return w;
          return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
        })
        .join(' ');
  }
}
