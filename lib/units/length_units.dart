/// Display units. Storage is always centimeters.
enum LengthUnitSystem {
  metric,
  imperial;

  String get label => this == LengthUnitSystem.metric ? 'Meters' : 'Feet';

  String get shortLabel => this == LengthUnitSystem.metric ? 'm' : 'ft';
}

class Units {
  const Units._();

  static const cmPerInch = 2.54;
  static const cmPerFoot = 30.48;

  static double cmToMeters(double cm) => cm / 100.0;
  static double cmToFeet(double cm) => cm / cmPerFoot;
  static double metersToCm(double m) => m * 100.0;
  static double feetToCm(double ft) => ft * cmPerFoot;

  /// Wall / opening length style: `3.20 m` or `10′ 6″`.
  static String formatLength(double cm, LengthUnitSystem system, {int decimals = 2}) {
    if (system == LengthUnitSystem.metric) {
      if (cm.abs() < 100) {
        return '${cm.round()} cm';
      }
      return '${cmToMeters(cm).toStringAsFixed(decimals)} m';
    }
    final totalInches = cm / cmPerInch;
    final feet = totalInches.floor() ~/ 12;
    final inches = (totalInches - feet * 12).round().clamp(0, 11);
    if (feet == 0) return '$inches″';
    if (inches == 0) return '$feet′';
    return '$feet′ $inches″';
  }

  /// Compact pair for catalog tiles: `1.8×0.9 m` or `5′11″×3′0″`.
  static String formatSize2d(
    double widthCm,
    double depthCm,
    LengthUnitSystem system,
  ) {
    return '${formatLength(widthCm, system, decimals: 1)}×'
        '${formatLength(depthCm, system, decimals: 1)}';
  }

  static String formatAreaM2(double areaM2, LengthUnitSystem system) {
    if (system == LengthUnitSystem.metric) {
      return '${areaM2.toStringAsFixed(1)} m²';
    }
    // 1 m² = 10.7639 ft²
    return '${(areaM2 * 10.7639).toStringAsFixed(0)} ft²';
  }

  /// Scale-bar caption for ~[barCm] of plan length.
  static String formatScaleBar(double barCm, LengthUnitSystem system) {
    return formatLength(barCm, system, decimals: barCm >= 100 ? 0 : 0);
  }
}
