import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/hm_colors.dart';

/// Soft translucent control surface (Liquid Glass–inspired, restrained).
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.padding,
    this.opacity = 0.78,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = (isDark ? HmColors.surfaceElevatedDark : HmColors.surfaceElevated)
        .withValues(alpha: opacity);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: (isDark ? HmColors.hairlineDark : HmColors.hairline)
                  .withValues(alpha: 0.7),
            ),
          ),
          child: padding == null ? child : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}
