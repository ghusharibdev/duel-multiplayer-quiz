import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/match.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'match_screen.dart';

class CountdownScreen extends StatefulWidget {
  final String matchId;
  final Match match;

  const CountdownScreen({
    super.key,
    required this.matchId,
    required this.match,
  });

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen>
    with SingleTickerProviderStateMixin {
  int _countdownValue = 3;
  Timer? _countdownTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the countdown number
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdownValue <= 1) {
        timer.cancel();
        setState(() => _countdownValue = 0);

        // Show "GO!" for 800ms, then navigate to match
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          _navigateToMatch();
        });
      } else {
        setState(() => _countdownValue--);
        _pulseController.forward(from: 0);
      }
    });

    // Start initial pulse
    _pulseController.forward(from: 0);
  }

  void _navigateToMatch() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MatchScreen(
          matchId: widget.matchId,
          startRound: 1,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final isPlayer1 = user?.uid == widget.match.player1Id;
    final opponentName = isPlayer1
        ? widget.match.player2Name
        : widget.match.player1Name;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Opponent avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colors.teal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.teal, width: 2),
                ),
                child: Center(
                  child: Text(
                    opponentName.isNotEmpty
                        ? opponentName[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: colors.teal,
                    ),
                  ),
                ),
              ).animate().scale(
                    duration: 300.ms,
                    curve: Curves.easeOutBack,
                  ),

              const SizedBox(height: 16),

              // Opponent name
              Text(
                'vs $opponentName',
                style: AppTypography.h1(color: colors.ink),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

              const SizedBox(height: 8),

              // Match info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.match.totalRounds} Rounds',
                  style: AppTypography.caption(color: colors.inkSubtle),
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

              const SizedBox(height: 64),

              // Countdown number
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  final displayText =
                      _countdownValue > 0 ? '$_countdownValue' : 'GO!';
                  final displayColor =
                      _countdownValue > 0 ? colors.coral : colors.teal;

                  return Transform.scale(
                    scale: _countdownValue > 0 ? _pulseAnimation.value : 1.0,
                    child: Text(
                      displayText,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: _countdownValue > 0 ? 120 : 80,
                        fontWeight: FontWeight.w900,
                        color: displayColor,
                        shadows: [
                          Shadow(
                            blurRadius: 30,
                            color: displayColor.withValues(alpha: 0.4),
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ).animate().scale(
                    duration: 300.ms,
                    curve: Curves.easeOutBack,
                  ),

              const SizedBox(height: 48),

              // Loading indicator
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colors.inkSubtle,
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
            ],
          ),
        ),
      ),
    );
  }
}
