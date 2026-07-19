import 'package:flutter/material.dart';

import '../services/star_rating_service.dart';

class StarRatingView extends StatelessWidget {
  const StarRatingView({
    super.key,
    required this.memberId,
    this.compact = false,
    this.showBreakdown = false,
  });

  final String memberId;
  final bool compact;
  final bool showBreakdown;

  @override
  Widget build(BuildContext context) {
    final r = StarRatingService.breakdown(memberId);
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            r.stars <= 0 ? '☆☆☆☆☆' : r.starsLabel,
            style: TextStyle(
              fontSize: 12,
              color: r.stars > 0 ? Colors.amber.shade800 : Colors.grey,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          r.starsLabel,
          style: TextStyle(
            fontSize: 22,
            color: r.stars > 0 ? Colors.amber.shade800 : Colors.grey,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        Text(
          r.stars <= 0
              ? 'Auto rating — activity se stars milenge'
              : '${r.stars}/5 · ${r.points} points (auto)',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        if (showBreakdown && r.reasons.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final line in r.reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('• $line', style: const TextStyle(fontSize: 13)),
            ),
        ],
      ],
    );
  }
}
