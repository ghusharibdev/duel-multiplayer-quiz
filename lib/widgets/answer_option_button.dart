import 'package:flutter/material.dart';
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
    Color backgroundColor;
    Color textColor;
    Color? borderColor;

    switch (state) {
      case AnswerState.idle:
        backgroundColor = AppColors.stone;
        textColor = AppColors.ink;
        borderColor = null;
        break;
      case AnswerState.selected:
        backgroundColor = AppColors.stone;
        textColor = AppColors.ink;
        borderColor = selectedByColor ?? AppColors.ink;
        break;
      case AnswerState.correct:
        backgroundColor = AppColors.gold;
        textColor = AppColors.ink;
        borderColor = AppColors.gold;
        break;
      case AnswerState.incorrect:
        backgroundColor = AppColors.stone;
        textColor = AppColors.inkDim;
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
          border: borderColor != null
              ? Border.all(color: borderColor, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: state == AnswerState.correct
                    ? AppColors.ink.withValues(alpha: 0.1)
                    : AppColors.cream,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: state == AnswerState.correct
                        ? AppColors.ink
                        : textColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
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
