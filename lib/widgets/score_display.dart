import 'package:flutter/material.dart';
import '../theme/app_typography.dart';

class ScoreDisplay extends StatelessWidget {
  final int score;
  final Color color;
  final String playerName;

  const ScoreDisplay({
    super.key,
    required this.score,
    required this.color,
    required this.playerName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          score.toString(),
          style: AppTypography.scoreDisplay(color: color),
        ),
        const SizedBox(height: 4),
        Text(
          playerName,
          style: AppTypography.caption(color: color),
        ),
      ],
    );
  }
}
