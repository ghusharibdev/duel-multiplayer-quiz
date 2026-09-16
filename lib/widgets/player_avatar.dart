import 'package:flutter/material.dart';
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? ringColor : AppColors.stone,
          width: 3,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w600,
            color: isActive ? ringColor : AppColors.stone,
          ),
        ),
      ),
    );
  }
}
