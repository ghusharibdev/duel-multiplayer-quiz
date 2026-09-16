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
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Finish line
              Positioned(
                right: 16,
                top: 16,
                child: Icon(
                  Icons.flag_rounded,
                  size: 12,
                  color: colors.inkFaint,
                ),
              ),
              // Player 1 marker
              AnimatedBuilder(
                animation: _player1Anim,
                builder: (context, _) {
                  return Positioned(
                    left: 16 + (_player1Anim.value * trackWidth).clamp(0.0, trackWidth),
                    top: 14,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors.coral,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.background, width: 2),
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
                    top: 14,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors.teal,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.background, width: 2),
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
