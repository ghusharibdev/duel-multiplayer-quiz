import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color card;
  final Color border;
  final Color ink;
  final Color inkSubtle;
  final Color inkFaint;

  final Color coral;
  final Color coralBright;
  final Color coralDim;
  final Color coralLight;
  final Color teal;
  final Color tealBright;
  final Color tealDim;
  final Color tealLight;
  final Color gold;
  final Color goldBright;

  final Color onAccent;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.card,
    required this.border,
    required this.ink,
    required this.inkSubtle,
    required this.inkFaint,
    required this.coral,
    required this.coralBright,
    required this.coralDim,
    required this.coralLight,
    required this.teal,
    required this.tealBright,
    required this.tealDim,
    required this.tealLight,
    required this.gold,
    required this.goldBright,
    required this.onAccent,
  });

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>()!;
  }

  factory AppColors.dark() => const AppColors(
        background: Color(0xFF0D1117),
        surface: Color(0xFF161B22),
        surfaceVariant: Color(0xFF1C2128),
        card: Color(0xFF21262D),
        border: Color(0xFF30363D),
        ink: Color(0xFFE6EDF3),
        inkSubtle: Color(0xFF8B949E),
        inkFaint: Color(0xFF484F58),
        coral: Color(0xFFF85149),
        coralBright: Color(0xFFFF7B72),
        coralDim: Color(0x40F85149),
        coralLight: Color(0x1AF85149),
        teal: Color(0xFF3FB950),
        tealBright: Color(0xFF56D364),
        tealDim: Color(0x403FB950),
        tealLight: Color(0x1A3FB950),
        gold: Color(0xFFD29922),
        goldBright: Color(0xFFE3B341),
        onAccent: Color(0xFF0D1117),
      );

  factory AppColors.light() => const AppColors(
        background: Color(0xFFFAF8F4),
        surface: Color(0xFFEFEBE4),
        surfaceVariant: Color(0xFFE4DFD7),
        card: Color(0xFFFFFFFF),
        border: Color(0xFFD4CFC7),
        ink: Color(0xFF171A1F),
        inkSubtle: Color(0xFF6B7280),
        inkFaint: Color(0xFF9CA3AF),
        coral: Color(0xFFE5533D),
        coralBright: Color(0xFFEF6F5C),
        coralDim: Color(0x33E5533D),
        coralLight: Color(0x1AE5533D),
        teal: Color(0xFF2FB8AC),
        tealBright: Color(0xFF4ECDC4),
        tealDim: Color(0x332FB8AC),
        tealLight: Color(0x1A2FB8AC),
        gold: Color(0xFFD9A441),
        goldBright: Color(0xFFE6B85C),
        onAccent: Color(0xFFFFFFFF),
      );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? card,
    Color? border,
    Color? ink,
    Color? inkSubtle,
    Color? inkFaint,
    Color? coral,
    Color? coralBright,
    Color? coralDim,
    Color? coralLight,
    Color? teal,
    Color? tealBright,
    Color? tealDim,
    Color? tealLight,
    Color? gold,
    Color? goldBright,
    Color? onAccent,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      card: card ?? this.card,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      inkSubtle: inkSubtle ?? this.inkSubtle,
      inkFaint: inkFaint ?? this.inkFaint,
      coral: coral ?? this.coral,
      coralBright: coralBright ?? this.coralBright,
      coralDim: coralDim ?? this.coralDim,
      coralLight: coralLight ?? this.coralLight,
      teal: teal ?? this.teal,
      tealBright: tealBright ?? this.tealBright,
      tealDim: tealDim ?? this.tealDim,
      tealLight: tealLight ?? this.tealLight,
      gold: gold ?? this.gold,
      goldBright: goldBright ?? this.goldBright,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSubtle: Color.lerp(inkSubtle, other.inkSubtle, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      coralBright: Color.lerp(coralBright, other.coralBright, t)!,
      coralDim: Color.lerp(coralDim, other.coralDim, t)!,
      coralLight: Color.lerp(coralLight, other.coralLight, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      tealBright: Color.lerp(tealBright, other.tealBright, t)!,
      tealDim: Color.lerp(tealDim, other.tealDim, t)!,
      tealLight: Color.lerp(tealLight, other.tealLight, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldBright: Color.lerp(goldBright, other.goldBright, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }

  // Convenience getters for legacy compat
  Color get cream => background;
  Color get stone => surface;
  Color get inkDim => coralDim;
}
