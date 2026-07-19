import '../models/member.dart';
import 'accounts_store.dart';
import 'board_store.dart';
import 'member_usage_store.dart';
import 'planner_store.dart';

class StarRatingResult {
  const StarRatingResult({
    required this.stars,
    required this.points,
    required this.reasons,
  });

  final int stars;
  final int points;
  final List<String> reasons;

  String get starsLabel => stars <= 0 ? '—' : ('★' * stars) + ('☆' * (5 - stars));
}

/// Auto star rating: fee, donation, PC, attendance, usage, extra work.
class StarRatingService {
  static Future<void> ensureData() async {
    await Future.wait([
      AccountsStore.ensureLoaded(),
      PlannerStore.ensureLoaded(),
      BoardStore.ensureLoaded(),
      MemberUsageStore.ensureLoaded(),
    ]);
  }

  static int starsFor(String memberId) => breakdown(memberId).stars;

  static StarRatingResult breakdown(String memberId) {
    final id = memberId.trim();
    if (id.isEmpty) {
      return const StarRatingResult(stars: 0, points: 0, reasons: []);
    }

    var points = 0;
    final reasons = <String>[];

    final fee = AccountsStore.feeForMember(id);
    if (fee != null && fee.paid) {
      points += 2;
      reasons.add('Membership fee jama (+2)');
      if (_isEarlyFee(fee.date)) {
        points += 2;
        reasons.add('Fee jaldi jama (+2)');
      }
    }
    if (fee != null && fee.boardPaid) {
      points += 1;
      reasons.add('Board fee jama (+1)');
    }

    final dons = AccountsStore.donations
        .where((d) => d.memberId == id)
        .toList();
    if (dons.isNotEmpty) {
      points += 2;
      reasons.add('Donation diya (${dons.length}) (+2)');
      final total = dons.fold<double>(0, (a, d) => a + d.amount);
      if (total >= 5000 || dons.length >= 2) {
        points += 1;
        reasons.add('Donation strong (₹${total.toStringAsFixed(0)}) (+1)');
      }
    }

    final asPc = PlannerStore.current
        .where((p) => p.pcsNormalized.contains(id))
        .toList();
    if (asPc.isNotEmpty) {
      final pcPts = (asPc.length * 2).clamp(0, 6);
      points += pcPts;
      reasons.add('Program PC ×${asPc.length} (+$pcPts)');
    }

    final asDir = PlannerStore.current
        .where((p) => p.directorMemberId.trim() == id)
        .toList();
    if (asDir.isNotEmpty) {
      final dPts = asDir.length.clamp(0, 2);
      points += dPts;
      reasons.add('Program Director ×${asDir.length} (+$dPts)');
    }

    final attended = PlannerStore.current
        .where((p) => p.attendedMemberIds.contains(id))
        .length;
    if (attended > 0) {
      final aPts = attended.clamp(0, 4);
      points += aPts;
      reasons.add('Program mein haziri ×$attended (+$aPts)');
    }

    if (BoardStore.postsForMember(id).isNotEmpty) {
      points += 1;
      reasons.add('Board post / zimmedari (+1)');
    }

    // Extra work: PC programs with good checklist progress.
    var extra = 0;
    for (final p in asPc) {
      final t = p.checklistTotal;
      if (t > 0 && p.checklistDoneCount / t >= 0.5) extra++;
    }
    if (extra > 0) {
      final ePts = extra.clamp(0, 2);
      points += ePts;
      reasons.add('Extra program work / checklist (+$ePts)');
    }

    final opens = MemberUsageStore.openCount(id);
    if (opens >= 5) {
      points += 1;
      reasons.add('App regularly use ($opens opens) (+1)');
    }
    if (opens >= 20) {
      points += 1;
      reasons.add('App zyada screen / engagement (+1)');
    }
    if (opens >= 50) {
      points += 1;
      reasons.add('Bahut active user (+1)');
    }

    final stars = _pointsToStars(points);
    if (stars == 0 && reasons.isEmpty) {
      reasons.add('Abhi activity kam — fee, program, donation se stars badhenge');
    }
    return StarRatingResult(stars: stars, points: points, reasons: reasons);
  }

  static int _pointsToStars(int points) {
    if (points <= 0) return 0;
    if (points <= 2) return 1;
    if (points <= 5) return 2;
    if (points <= 9) return 3;
    if (points <= 14) return 4;
    return 5;
  }

  /// Lions year: July–Sep mein fee = jaldi.
  static bool _isEarlyFee(String dateRaw) {
    final d = Member.parseFlexibleDate(dateRaw);
    if (d == null) return false;
    return d.month >= 7 && d.month <= 9;
  }
}
