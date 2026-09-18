import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/game_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/player_avatar.dart';
import '../widgets/score_display.dart';
import '../widgets/answer_option_button.dart';
import '../widgets/live_answer_race.dart';
import 'round_result_screen.dart';
import 'match_result_screen.dart';

class MatchScreen extends ConsumerStatefulWidget {
  final String matchId;
  final int startRound;

  const MatchScreen({
    super.key,
    required this.matchId,
    this.startRound = 1,
  });

  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen> {
  int? _selectedAnswer;
  bool _hasSubmitted = false;
  bool _navigated = false;
  bool _tapLocked = false;
  @override
  void initState() {
    super.initState();
    ref.read(gameServiceProvider).listenToMatchById(widget.matchId);
  }

  void _submitAnswer(int answerIndex) {
    if (_tapLocked) return;
    _tapLocked = true;

    setState(() {
      _hasSubmitted = true;
      _selectedAnswer = answerIndex;
    });

    ref.read(gameServiceProvider).submitAnswer(answerIndex);
  }

  Future<bool> _onWillPop() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = AppColors.of(context);
        return AlertDialog(
          backgroundColor: colors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Leave Match?', style: AppTypography.h1(color: colors.ink)),
          content: Text(
            'Are you sure you want to leave this match? You will forfeit the game.',
            style: AppTypography.body(color: colors.inkSubtle),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: AppTypography.body(color: colors.ink)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Leave', style: AppTypography.body(color: colors.coral)),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final matchAsync = ref.watch(matchByIdProvider(widget.matchId));
    final user = FirebaseAuth.instance.currentUser;

    // The round index this screen is responsible for (0-based)
    final myRoundIndex = widget.startRound - 1;

    // Listen for round resolution — ref.listen must be called inside build()
    // in Riverpod 3.x. Riverpod deduplicates listeners per rebuild cycle.
    ref.listen(matchByIdProvider(widget.matchId), (previous, next) {
      if (_navigated) return;
      final match = next.value;
      if (match == null) return;

      // Check if OUR round just resolved — this MUST come before isFinished
      // because on the final round, _resolveRoundIfReady sets both
      // status='completed' AND resolved=true in the same transaction.
      if (myRoundIndex >= 0 &&
          myRoundIndex < match.rounds.length &&
          match.rounds[myRoundIndex].resolved &&
          mounted) {
        _navigated = true;
        final targetRound = match.rounds[myRoundIndex];
        final isP1 = user?.uid == match.player1Id;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RoundResultScreen(
              matchId: match.id,
              currentRound: widget.startRound,
              totalRounds: match.totalRounds,
              player1Score: match.player1Score,
              player2Score: match.player2Score,
              player1Answer: targetRound.player1Answer,
              player2Answer: targetRound.player2Answer,
              correctIndex: targetRound.correctIndex,
              isPlayer1: isP1,
            ),
          ),
        );
        return;
      }

      // If match finished but our round didn't resolve (shouldn't happen),
      // navigate to results as a safety net
      if (match.isFinished && mounted) {
        _navigated = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MatchResultScreen(
              matchId: match.id,
              player1Score: match.player1Score,
              player2Score: match.player2Score,
              player1Id: match.player1Id,
            ),
          ),
        );
        return;
      }

      // Reset answer state when round changes
      final prevMatch = previous?.value;
      if (match.currentRound != prevMatch?.currentRound) {
        setState(() {
          _selectedAnswer = null;
          _hasSubmitted = false;
          _tapLocked = false;
        });
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Stack(
            children: [
              matchAsync.when(
                loading: () => Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(color: colors.coral),
                  ),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (match) {
                  if (match == null) {
                    return const Center(child: Text('Match not found'));
                  }

                  // Match finished — show final result
                  if (match.isFinished) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: colors.coral),
                          const SizedBox(height: 16),
                          Text(
                            'Loading final results...',
                            style: AppTypography.body(
                                color: colors.inkSubtle),
                          ),
                        ],
                      ),
                    );
                  }

                  // Opponent hasn't joined yet
                  if (match.player2Id.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: colors.teal),
                          const SizedBox(height: 16),
                          Text(
                            'Waiting for opponent...',
                            style: AppTypography.body(
                                color: colors.inkSubtle),
                          ),
                        ],
                      ),
                    );
                  }

                  // Validate our round index
                  if (myRoundIndex < 0 ||
                      myRoundIndex >= match.rounds.length) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: colors.coral),
                          const SizedBox(height: 16),
                          Text(
                            'Waiting for round to start...',
                            style: AppTypography.body(
                                color: colors.inkSubtle),
                          ),
                        ],
                      ),
                    );
                  }

              final roundData = match.rounds[myRoundIndex];
              final displayRound = widget.startRound;
              final isPlayer1 = user?.uid == match.player1Id;

              final myScore = isPlayer1 ? match.player1Score : match.player2Score;
              final oppScore = isPlayer1 ? match.player2Score : match.player1Score;
              final myAnswer = isPlayer1 ? roundData.player1Answer : roundData.player2Answer;
              final opponentAnswer = isPlayer1 ? roundData.player2Answer : roundData.player1Answer;

              double myProgress = 0.1;
              if (myAnswer != null) {
                myProgress = 1.0;
              } else if (_selectedAnswer != null) {
                myProgress = 0.6;
              }

              double opponentProgress = 0.1;
              if (opponentAnswer != null) {
                opponentProgress = 1.0;
              } else if (_hasSubmitted) {
                opponentProgress = 0.3;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),

                    Text(
                      'Round $displayRound of ${match.totalRounds}',
                      style: AppTypography.caption(color: colors.inkSubtle),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Score row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            PlayerAvatar(
                              label: 'You',
                              ringColor: colors.coral,
                              size: 56,
                              isActive: myAnswer == null,
                            ),
                            const SizedBox(height: 8),
                            ScoreDisplay(score: myScore, color: colors.coral, playerName: 'You'),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'VS',
                            style: GoogleFonts.hankenGrotesk(fontSize: 16, fontWeight: FontWeight.w600, color: colors.ink),
                          ),
                        ),
                        Column(
                          children: [
                            PlayerAvatar(
                              label: 'Opp',
                              ringColor: colors.teal,
                              size: 56,
                              isActive: opponentAnswer == null,
                            ),
                            const SizedBox(height: 8),
                            ScoreDisplay(score: oppScore, color: colors.teal, playerName: 'Opponent'),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Text(
                      roundData.questionText,
                      style: AppTypography.h1(color: colors.ink),
                      textAlign: TextAlign.left,
                    ),

                    const SizedBox(height: 20),

                    // Answer options
                    Expanded(
                      child: ListView.separated(
                        itemCount: roundData.options.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          AnswerState state = AnswerState.idle;
                          Color? borderColor;

                          final bothAnswered = roundData.bothAnswered;

                          if (bothAnswered && index == roundData.correctIndex) {
                            state = AnswerState.correct;
                          } else if (bothAnswered &&
                              index == _selectedAnswer &&
                              index != roundData.correctIndex) {
                            state = AnswerState.incorrect;
                            borderColor = colors.coral;
                          } else if (_hasSubmitted && index == _selectedAnswer) {
                            state = AnswerState.selected;
                            borderColor = colors.coral;
                          }

                          return AnswerOptionButton(
                            label: String.fromCharCode(65 + index),
                            text: roundData.options[index],
                            state: state,
                            selectedByColor: borderColor,
                            onTap: _tapLocked ? null : () => _submitAnswer(index),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    LiveAnswerRace(
                      player1Progress: myProgress,
                      player2Progress: opponentProgress,
                      showResults: _hasSubmitted,
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.coral,
                          foregroundColor: colors.background,
                          disabledBackgroundColor: _hasSubmitted
                              ? colors.teal.withValues(alpha: 0.3)
                              : colors.surfaceVariant,
                          disabledForegroundColor: _hasSubmitted
                              ? colors.teal
                              : colors.inkFaint,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          _hasSubmitted ? 'Waiting for opponent...' : 'Select an answer',
                          style: GoogleFonts.hankenGrotesk(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onAccent),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),


            ],
          ),
        ),
      ),
    );
  }


}
