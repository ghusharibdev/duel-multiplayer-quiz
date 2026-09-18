import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

class LiveAnswerRace extends StatefulWidget {
  final double player1Progress;
  final double player2Progress;
  final bool showResults;

  const LiveAnswerRace({
    super.key,
    required this.player1Progress,
    required this.player2Progress,
    this.showResults = false,
  });

  @override
  State<LiveAnswerRace> createState() => _LiveAnswerRaceState();
}

class _LiveAnswerRaceState extends State<LiveAnswerRace>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _player1Anim;
  late Animation<double> _player2Anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _player1Anim = AlwaysStoppedAnimation(widget.player1Progress);
    _player2Anim = AlwaysStoppedAnimation(widget.player2Progress);

    _controller.forward();
  }

  @override
  void didUpdateWidget(LiveAnswerRace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player1Progress != widget.player1Progress ||
        oldWidget.player2Progress != widget.player2Progress) {
      _player1Anim = Tween<double>(
        begin: oldWidget.player1Progress,
        end: widget.player1Progress,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));
      _player2Anim = Tween<double>(
        begin: oldWidget.player2Progress,
        end: widget.player2Progress,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth - 32;
          return Stack(
            children: [
              // Track background
              Positioned(
                left: 16,
                right: 16,
                top: 20,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              // Finish line
              Positioned(
                right: 16,
                top: 14,
                child: Icon(
                  Icons.flag_rounded,
                  size: 14,
                  color: colors.ink.withValues(alpha: 0.5),
                ),
              ),
              // Player 1 marker
              AnimatedBuilder(
                animation: _player1Anim,
                builder: (context, _) {
                  return Positioned(
                    left: 16 + (_player1Anim.value * trackWidth).clamp(0.0, trackWidth),
                    top: 12,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: colors.coral,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.background, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: colors.coral.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Player 2 marker
              AnimatedBuilder(
                animation: _player2Anim,
                builder: (context, _) {
                  return Positioned(
                    left: 16 + (_player2Anim.value * trackWidth).clamp(0.0, trackWidth),
                    top: 12,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: colors.teal,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.background, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: colors.teal.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
