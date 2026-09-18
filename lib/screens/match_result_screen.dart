import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/primary_button.dart';
import '../widgets/secondary_button.dart';

class MatchResultScreen extends StatelessWidget {
  final String matchId;
  final int player1Score;
  final int player2Score;
  final String player1Id;

  const MatchResultScreen({
    super.key,
    required this.matchId,
    required this.player1Score,
    required this.player2Score,
    required this.player1Id,
  });

  bool get _isPlayer1 => FirebaseAuth.instance.currentUser?.uid == player1Id;
  int get _myScore => _isPlayer1 ? player1Score : player2Score;
  int get _oppScore => _isPlayer1 ? player2Score : player1Score;
  bool get _player1Won => player1Score > player2Score;
  bool get _isDraw => player1Score == player2Score;
  bool get _iWon => _isDraw ? false : (_player1Won == _isPlayer1);

  Color _resultColor(BuildContext context) {
    final colors = AppColors.of(context);
    if (_isDraw) return colors.gold;
    return _iWon ? colors.teal : colors.coral;
  }

  String get _shareText {
    if (_isDraw) return 'We drew $_myScore-$_oppScore on Duel! Can you beat me? 🤝';
    if (_iWon) return 'I won $_myScore-$_oppScore on Duel! 💪 Think you can beat me?';
    return 'Lost $_myScore-$_oppScore on Duel... Want a rematch? 😤';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final resultColor = _resultColor(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Result icon
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: resultColor,
                    width: 3,
                  ),
                ),
                child: Icon(
                  _isDraw
                      ? Icons.handshake_rounded
                      : (_iWon ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded),
                  size: 52,
                  color: resultColor,
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 28),

              // Result text
              Text(
                _isDraw ? 'Draw!' : (_iWon ? 'You Won!' : 'You Lost'),
                style: AppTypography.display(color: resultColor),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

              const SizedBox(height: 12),

              // Score
              Text(
                '$_myScore - $_oppScore',
                style: AppTypography.scoreDisplay(color: colors.ink),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

              const Spacer(flex: 3),

              // Share button (primary action)
              PrimaryButton(
                label: 'Share Result',
                onPressed: () => Share.share(_shareText),
              ),

              const SizedBox(height: 12),

              // Back to Home
              SecondaryButton(
                label: 'Back to Home',
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
