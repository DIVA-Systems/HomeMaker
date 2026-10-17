import 'package:flutter/cupertino.dart';

/// Semantic palette — architectural studio, not generic AI purple/cream.
/// Light-first; dark variants included for system appearance.
@immutable
class HmColors {
  const HmColors._();

  // Brand / accent — deep spruce (architectural ink-green)
  static const Color spruce = Color(0xFF1F4D45);
  static const Color spruceSoft = Color(0xFF2F6B60);
  static const Color clay = Color(0xFFC56A3C); // sparse accent for primary CTAs only

  // Surfaces (light)
  static const Color canvas = Color(0xFFF3EFE7); // plan paper
  static const Color canvasGrid = Color(0xFFE4DDD0);
  static const Color surface = Color(0xFFFAF8F4);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceGrouped = Color(0xFFEDE8DF);
  static const Color hairline = Color(0xFFD6CFC2);

  // Ink
  static const Color ink = Color(0xFF1A1C1A);
  static const Color inkSecondary = Color(0xFF5C635C);
  static const Color inkTertiary = Color(0xFF8A9188);
  static const Color inkOnAccent = Color(0xFFF7F4EE);

  // Plan semantics
  static const Color wall = Color(0xFF2A2E2C);
  static const Color wallSelected = Color(0xFF1F4D45);
  static const Color roomFill = Color(0x33C56A3C);
  static const Color selection = Color(0xFF2F6B60);
  static const Color danger = Color(0xFFB42318);

  // Dark appearance
  static const Color canvasDark = Color(0xFF1C1E1C);
  static const Color canvasGridDark = Color(0xFF2A2D2A);
  static const Color surfaceDark = Color(0xFF121412);
  static const Color surfaceElevatedDark = Color(0xFF1E211E);
  static const Color surfaceGroupedDark = Color(0xFF161816);
  static const Color hairlineDark = Color(0xFF3A3F3A);
  static const Color inkDark = Color(0xFFF2F0EA);
  static const Color inkSecondaryDark = Color(0xFFA8AFA6);
  static const Color inkTertiaryDark = Color(0xFF7A8178);

  static CupertinoDynamicColor dynamic({
    required Color light,
    required Color dark,
  }) =>
      CupertinoDynamicColor.withBrightness(color: light, darkColor: dark);

  static final CupertinoDynamicColor background = dynamic(
    light: surface,
    dark: surfaceDark,
  );
  static final CupertinoDynamicColor groupedBackground = dynamic(
    light: surfaceGrouped,
    dark: surfaceGroupedDark,
  );
  static final CupertinoDynamicColor elevated = dynamic(
    light: surfaceElevated,
    dark: surfaceElevatedDark,
  );
  static final CupertinoDynamicColor label = dynamic(
    light: ink,
    dark: inkDark,
  );
  static final CupertinoDynamicColor secondaryLabel = dynamic(
    light: inkSecondary,
    dark: inkSecondaryDark,
  );
  static final CupertinoDynamicColor tertiaryLabel = dynamic(
    light: inkTertiary,
    dark: inkTertiaryDark,
  );
  static final CupertinoDynamicColor separator = dynamic(
    light: hairline,
    dark: hairlineDark,
  );
  static final CupertinoDynamicColor planCanvas = dynamic(
    light: canvas,
    dark: canvasDark,
  );
  static final CupertinoDynamicColor planGrid = dynamic(
    light: canvasGrid,
    dark: canvasGridDark,
  );
}
