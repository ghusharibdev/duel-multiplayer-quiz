import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static TextStyle _spaceGrotesk({
    double fontSize = 16,
    double height = 1.5,
    int weight = 400,
    Color color = AppColors.ink,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      height: height,
      fontWeight: FontWeight.values[weight ~/ 100],
      color: color,
    );
  }

  static TextStyle _inter({
    double fontSize = 16,
    double height = 1.5,
    int weight = 400,
    Color color = AppColors.ink,
    bool tabularFigures = false,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      height: height,
      fontWeight: FontWeight.values[weight ~/ 100],
      color: color,
      fontFeatures: tabularFigures ? [const FontFeature.tabularFigures()] : [],
    );
  }

  // Score display — Space Grotesk 48/52 weight 700
  static TextStyle scoreDisplay({Color color = AppColors.ink}) => _spaceGrotesk(
        fontSize: 48,
        height: 52 / 48,
        weight: 700,
        color: color,
      );

  // Display — Space Grotesk 28/34 weight 600
  static TextStyle display({Color color = AppColors.ink}) => _spaceGrotesk(
        fontSize: 28,
        height: 34 / 28,
        weight: 600,
        color: color,
      );

  // H1 — Space Grotesk 22/28 weight 600
  static TextStyle h1({Color color = AppColors.ink}) => _spaceGrotesk(
        fontSize: 22,
        height: 28 / 22,
        weight: 600,
        color: color,
      );

  // Body — Inter 16/24
  static TextStyle body({Color color = AppColors.ink}) => _inter(
        fontSize: 16,
        height: 24 / 16,
        weight: 400,
        color: color,
      );

  // Caption — Inter 13/18
  static TextStyle caption({Color color = AppColors.ink}) => _inter(
        fontSize: 13,
        height: 18 / 13,
        weight: 400,
        color: color,
      );

  // Timer / numerals with tabular figures — Inter
  static TextStyle timer({Color color = AppColors.ink}) => _inter(
        fontSize: 16,
        height: 24 / 16,
        weight: 500,
        color: color,
        tabularFigures: true,
      );
}
