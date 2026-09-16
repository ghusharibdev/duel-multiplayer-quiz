import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
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
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _iWon
                      ? colors.gold
                      : _isDraw
                          ? colors.surface
                          : colors.teal.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iWon
                      ? Icons.emoji_events_rounded
                      : _isDraw
                          ? Icons.handshake_rounded
                          : Icons.sentiment_dissatisfied_rounded,
                  size: 48,
                  color: _iWon
                      ? colors.background
                      : _isDraw
                          ? colors.ink
                          : colors.teal,
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOut),

              const SizedBox(height: 32),

              // Result text
              Text(
                _isDraw ? 'Draw' : (_iWon ? 'You won' : 'You lost'),
                style: AppTypography.display(
                  color: _iWon
                      ? colors.gold
                      : _isDraw
                          ? colors.ink
                          : colors.teal,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

              const SizedBox(height: 16),

              // Score text
              Text(
                '$_myScore - $_oppScore',
                style: AppTypography.scoreDisplay(
                  color: colors.ink,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

              const Spacer(flex: 2),

              // Action buttons
              PrimaryButton(
                label: 'Rematch',
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),

              const SizedBox(height: 12),

              SecondaryButton(
                label: 'Back to Home',
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),

              const SizedBox(height: 24),

              // Share button
              TextButton.icon(
                onPressed: () {
                  final result = _isDraw
                      ? 'Drew a Duel match $_myScore-$_oppScore!'
                      : (_iWon
                          ? 'Won a Duel match $_myScore-$_oppScore!'
                          : 'Lost a Duel match $_myScore-$_oppScore');
                  Clipboard.setData(ClipboardData(text: result));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Result copied to clipboard!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text(
                  'Share Result',
                  style: AppTypography.body(color: colors.ink),
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
