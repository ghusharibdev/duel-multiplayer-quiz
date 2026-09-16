import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match.dart';
import '../providers/game_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'match_screen.dart';
import 'match_result_screen.dart';

class RoundResultScreen extends ConsumerStatefulWidget {
  final String matchId;
  final int currentRound;
  final int totalRounds;
  final int player1Score;
  final int player2Score;
  final PlayerAnswer? player1Answer;
  final PlayerAnswer? player2Answer;
  final int correctIndex;
  final bool isPlayer1;

  const RoundResultScreen({
    super.key,
    required this.matchId,
    required this.currentRound,
    required this.totalRounds,
    required this.player1Score,
    required this.player2Score,
    this.player1Answer,
    this.player2Answer,
    required this.correctIndex,
    required this.isPlayer1,
  });

  @override
  ConsumerState<RoundResultScreen> createState() => _RoundResultScreenState();
}

class _RoundResultScreenState extends ConsumerState<RoundResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scoreController;
  late Animation<int> _player1ScoreAnim;
  late Animation<int> _player2ScoreAnim;
  Timer? _autoAdvanceTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Calculate what the previous scores were (current minus points from this round)
    int prevP1 = widget.player1Score;
    int prevP2 = widget.player2Score;

    final p1Answered = widget.player1Answer != null && widget.player1Answer!.isCorrect;
    final p2Answered = widget.player2Answer != null && widget.player2Answer!.isCorrect;

    if (p1Answered && p2Answered) {
      // Both correct — faster gets 10, slower gets 7
      final p1Time = widget.player1Answer!.timeMs;
      final p2Time = widget.player2Answer!.timeMs;
      if (p1Time <= p2Time) {
        prevP1 -= 10;
        prevP2 -= 7;
      } else {
        prevP1 -= 7;
        prevP2 -= 10;
      }
    } else if (p1Answered) {
      prevP1 -= 10;
    } else if (p2Answered) {
      prevP2 -= 10;
    }
    // Clamp to non-negative
    prevP1 = prevP1.clamp(0, widget.player1Score);
    prevP2 = prevP2.clamp(0, widget.player2Score);

    _scoreController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _player1ScoreAnim = IntTween(
      begin: prevP1,
      end: widget.player1Score,
    ).animate(CurvedAnimation(
      parent: _scoreController,
      curve: Curves.easeOut,
    ));

    _player2ScoreAnim = IntTween(
      begin: prevP2,
      end: widget.player2Score,
    ).animate(CurvedAnimation(
      parent: _scoreController,
      curve: Curves.easeOut,
    ));

    _scoreController.forward();

    // Auto-advance after 3 seconds
    _autoAdvanceTimer = Timer(const Duration(seconds: 3), () {
      _navigateToNext();
    });
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  void _navigateToNext() {
    if (!mounted || _navigated) return;
    _navigated = true;

    if (widget.currentRound >= widget.totalRounds) {
      // Match is complete — watch for the match to update
      _waitForMatchCompletion();
    } else {
      // Next round
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MatchScreen(matchId: widget.matchId),
        ),
      );
    }
  }

  void _waitForMatchCompletion() {
    // Listen for the match to be marked completed
    ref.listen<AsyncValue<Match?>>(currentMatchProvider, (previous, next) {
      final match = next.value;
      if (match != null && match.isFinished && mounted && !_navigated) {
        _navigated = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MatchResultScreen(
              matchId: widget.matchId,
              player1Score: match.player1Score,
              player2Score: match.player2Score,
              player1Id: match.player1Id,
            ),
          ),
        );
      }
    });

    // Also navigate after a delay as fallback
    Timer(const Duration(seconds: 2), () {
      if (mounted && !_navigated) {
        _navigated = true;
        final matchAsync = ref.read(currentMatchProvider);
        final match = matchAsync.value;
        if (match != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => MatchResultScreen(
                matchId: widget.matchId,
                player1Score: match.player1Score,
                player2Score: match.player2Score,
                player1Id: match.player1Id,
              ),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final myAnswer = widget.isPlayer1 ? widget.player1Answer : widget.player2Answer;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Round label
              Text(
                'Round ${widget.currentRound} of ${widget.totalRounds}',
                style: AppTypography.caption(
                  color: colors.inkSubtle,
                ),
              ),

              const SizedBox(height: 16),

              // Round result header
              Text(
                'Round Complete',
                style: AppTypography.display(color: colors.ink),
              ),

              const SizedBox(height: 48),

              // Answer race resolve visualization
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Positioned(
                          left: 16,
                          right: 16,
                          top: 20,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        // My marker at finish
                        Positioned(
                          right: 16,
                          top: 14,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: widget.isPlayer1 ? colors.coral : colors.teal,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.gold,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                        // Opponent marker behind
                        Positioned(
                          right: 80,
                          top: 14,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: widget.isPlayer1 ? colors.teal : colors.coral,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.background,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 48),

              // Answer result
              if (myAnswer != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: myAnswer.isCorrect
                        ? colors.gold.withValues(alpha: 0.2)
                        : colors.coral.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: myAnswer.isCorrect ? colors.gold : colors.coral,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        myAnswer.isCorrect ? Icons.check_circle : Icons.cancel,
                        color: myAnswer.isCorrect ? colors.gold : colors.coral,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              myAnswer.isCorrect ? 'Correct!' : 'Incorrect',
                              style: AppTypography.body(
                                color: myAnswer.isCorrect ? colors.gold : colors.coral,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Scores with count-up animation
              AnimatedBuilder(
                animation: _scoreController,
                builder: (context, child) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _AnimatedScore(
                        label: 'You',
                        score: widget.isPlayer1
                            ? _player1ScoreAnim.value
                            : _player2ScoreAnim.value,
                        color: widget.isPlayer1 ? colors.coral : colors.teal,
                      ),
                      _AnimatedScore(
                        label: 'Opponent',
                        score: widget.isPlayer1
                            ? _player2ScoreAnim.value
                            : _player1ScoreAnim.value,
                        color: widget.isPlayer1 ? colors.teal : colors.coral,
                      ),
                    ],
                  );
                },
              ),

              const Spacer(flex: 2),

              // Next round prompt
              Text(
                widget.currentRound >= widget.totalRounds
                    ? 'Final results coming up...'
                    : 'Next round starting soon...',
                style: AppTypography.body(
                  color: colors.inkSubtle,
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

class _AnimatedScore extends StatelessWidget {
  final String label;
  final int score;
  final Color color;

  const _AnimatedScore({
    required this.label,
    required this.score,
    required this.color,
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
          label,
          style: AppTypography.caption(color: color),
        ),
      ],
    );
  }
}
