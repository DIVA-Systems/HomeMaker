import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'hm_colors.dart';

class HmTheme {
  const HmTheme._();

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.light ? HmColors.ink : HmColors.inkDark;
    final secondary =
        brightness == Brightness.light ? HmColors.inkSecondary : HmColors.inkSecondaryDark;

    // Brand display: Newsreader. UI: Source Sans 3 — not Inter/Roboto.
    final display = GoogleFonts.newsreader(
      color: base,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      height: 1.15,
    );
    final body = GoogleFonts.sourceSans3(
      color: base,
      fontWeight: FontWeight.w400,
      height: 1.35,
    );

    return TextTheme(
      displayLarge: display.copyWith(fontSize: 40),
      displayMedium: display.copyWith(fontSize: 32),
      displaySmall: display.copyWith(fontSize: 28),
      headlineLarge: display.copyWith(fontSize: 26),
      headlineMedium: display.copyWith(fontSize: 22),
      headlineSmall: display.copyWith(fontSize: 20),
      titleLarge: body.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: body.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
      titleSmall: body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: body.copyWith(fontSize: 17),
      bodyMedium: body.copyWith(fontSize: 15),
      bodySmall: body.copyWith(fontSize: 13, color: secondary),
      labelLarge: body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      labelMedium: body.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      labelSmall: body.copyWith(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2),
    );
  }

  static ThemeData material(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: HmColors.spruce,
      onPrimary: HmColors.inkOnAccent,
      secondary: HmColors.clay,
      onSecondary: HmColors.inkOnAccent,
      error: HmColors.danger,
      onError: Colors.white,
      surface: isLight ? HmColors.surface : HmColors.surfaceDark,
      onSurface: isLight ? HmColors.ink : HmColors.inkDark,
      surfaceContainerHighest:
          isLight ? HmColors.surfaceGrouped : HmColors.surfaceGroupedDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: _textTheme(brightness),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: isLight ? HmColors.hairline : HmColors.hairlineDark,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: _textTheme(brightness).titleLarge,
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: HmColors.spruce,
        scaffoldBackgroundColor: scheme.surface,
        barBackgroundColor: (isLight ? HmColors.surface : HmColors.surfaceDark)
            .withValues(alpha: 0.82),
        textTheme: CupertinoTextThemeData(
          primaryColor: scheme.onSurface,
          textStyle: _textTheme(brightness).bodyLarge!,
          navTitleTextStyle: _textTheme(brightness).titleMedium!,
          navLargeTitleTextStyle: _textTheme(brightness).displaySmall!,
          actionTextStyle: _textTheme(brightness).labelLarge!.copyWith(
                color: HmColors.spruceSoft,
              ),
        ),
      ),
    );
  }

  static CupertinoThemeData cupertino(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: HmColors.spruce,
      scaffoldBackgroundColor: isLight ? HmColors.surface : HmColors.surfaceDark,
      barBackgroundColor:
          (isLight ? HmColors.surface : HmColors.surfaceDark).withValues(alpha: 0.82),
    );
  }
}
