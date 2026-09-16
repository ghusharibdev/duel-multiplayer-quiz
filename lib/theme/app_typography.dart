import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._();

  static TextStyle _spaceGrotesk({
    double fontSize = 16,
    double height = 1.5,
    int weight = 400,
    required Color color,
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
    required Color color,
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

  static TextStyle scoreDisplay({required Color color}) => _spaceGrotesk(
        fontSize: 48,
        height: 52 / 48,
        weight: 700,
        color: color,
      );

  static TextStyle display({required Color color}) => _spaceGrotesk(
        fontSize: 28,
        height: 34 / 28,
        weight: 600,
        color: color,
      );

  static TextStyle h1({required Color color}) => _spaceGrotesk(
        fontSize: 22,
        height: 28 / 22,
        weight: 600,
        color: color,
      );

  static TextStyle body({required Color color}) => _inter(
        fontSize: 16,
        height: 24 / 16,
        weight: 400,
        color: color,
      );

  static TextStyle caption({required Color color}) => _inter(
        fontSize: 13,
        height: 18 / 13,
        weight: 400,
        color: color,
      );

  static TextStyle timer({required Color color}) => _inter(
        fontSize: 16,
        height: 24 / 16,
        weight: 500,
        color: color,
        tabularFigures: true,
      );
}
