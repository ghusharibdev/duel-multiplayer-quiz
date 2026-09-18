import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

enum AnswerState { idle, selected, correct, incorrect }

class AnswerOptionButton extends StatelessWidget {
  final String label;
  final String text;
  final VoidCallback? onTap;
  final AnswerState state;
  final Color? selectedByColor;

  const AnswerOptionButton({
    super.key,
    required this.label,
    required this.text,
    this.onTap,
    this.state = AnswerState.idle,
    this.selectedByColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Color backgroundColor;
    Color textColor;
    Color? borderColor;

    switch (state) {
      case AnswerState.idle:
        backgroundColor = colors.surfaceVariant;
        textColor = colors.ink;
        borderColor = null;
        break;
      case AnswerState.selected:
        backgroundColor = colors.surfaceVariant;
        textColor = colors.ink;
        borderColor = selectedByColor ?? colors.border;
        break;
      case AnswerState.correct:
        backgroundColor = colors.gold.withValues(alpha: 0.2);
        textColor = colors.goldBright;
        borderColor = colors.gold;
        break;
      case AnswerState.incorrect:
        backgroundColor = colors.surfaceVariant;
        textColor = colors.inkFaint;
        borderColor = selectedByColor;
        break;
    }

    return GestureDetector(
      onTap: state == AnswerState.idle ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor ?? colors.border.withValues(alpha: 0.3),
            width: borderColor != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: state == AnswerState.correct
                    ? colors.gold.withValues(alpha: 0.3)
                    : colors.card,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: state == AnswerState.correct
                        ? colors.goldBright
                        : textColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),              Expanded(
              child: Text(
                text,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
