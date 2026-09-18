import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class PlayerAvatar extends StatelessWidget {
  final String label;
  final Color ringColor;
  final double size;
  final bool isActive;

  const PlayerAvatar({
    super.key,
    required this.label,
    required this.ringColor,
    this.size = 56,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceVariant,
        border: Border.all(
          color: isActive ? ringColor : colors.border,
          width: 3,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w600,
            color: isActive ? ringColor : colors.inkFaint,
          ),
        ),
      ),
    );
  }
}
