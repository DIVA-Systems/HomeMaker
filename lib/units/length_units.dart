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
  static String formatLength(
    double cm,
    LengthUnitSystem system, {
    int decimals = 2,
    bool preferCompactMetric = true,
  }) {
    if (system == LengthUnitSystem.metric) {
      if (preferCompactMetric && cm.abs() < 100) {
        return '${cm.round()} cm';
      }
      return '${cmToMeters(cm).toStringAsFixed(decimals)} m';
    }
    final totalInches = cm / cmPerInch;
    var feet = totalInches.floor() ~/ 12;
    var inches = (totalInches - feet * 12).round();
    if (inches == 12) {
      feet += 1;
      inches = 0;
    }
    if (feet == 0) return '$inches″';
    if (inches == 0) return '$feet′';
    return '$feet′ $inches″';
  }

  /// Compact pair for catalog tiles — always respects m vs ft setting.
  static String formatSize2d(
    double widthCm,
    double depthCm,
    LengthUnitSystem system,
  ) {
    if (system == LengthUnitSystem.metric) {
      return '${cmToMeters(widthCm).toStringAsFixed(2)}×'
          '${cmToMeters(depthCm).toStringAsFixed(2)} m';
    }
    return '${formatLength(widthCm, system)} × ${formatLength(depthCm, system)}';
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

  /// Parse user length text → cm. Accepts `3.5`, `350`, `3.5 m`, `12' 6"`, `12.5`.
  static double? parseLengthToCm(String raw, LengthUnitSystem system) {
    final t = raw.trim().toLowerCase().replaceAll(',', '.');
    if (t.isEmpty) return null;

    // Feet + inches: 12' 6" / 12′ 6″ / 12 ft 6 in
    final ftIn = RegExp(
      r'''^\s*(\d+(?:\.\d+)?)\s*(?:'|′|ft)\s*(\d+(?:\.\d+)?)?\s*(?:"|″|in)?\s*$''',
    ).firstMatch(t);
    if (ftIn != null) {
      final ft = double.tryParse(ftIn.group(1)!) ?? 0;
      final inches = double.tryParse(ftIn.group(2) ?? '0') ?? 0;
      return feetToCm(ft) + inches * cmPerInch;
    }

    final onlyInches = RegExp(r'''^\s*(\d+(?:\.\d+)?)\s*(?:"|″|in)\s*$''')
        .firstMatch(t);
    if (onlyInches != null) {
      return (double.tryParse(onlyInches.group(1)!) ?? 0) * cmPerInch;
    }

    final numMatch = RegExp(r'(-?\d+(?:\.\d+)?)').firstMatch(t);
    if (numMatch == null) return null;
    final v = double.tryParse(numMatch.group(1)!);
    if (v == null) return null;

    if (t.contains('cm')) return v;
    if (t.contains('mm')) return v / 10;
    if (t.contains('m') && !t.contains('mm') && !t.contains('cm')) {
      return metersToCm(v);
    }
    if (t.contains('ft') || t.contains('feet')) return feetToCm(v);

    // Bare number: metric → meters if small, cm if large; imperial → feet
    if (system == LengthUnitSystem.imperial) {
      return feetToCm(v);
    }
    if (v.abs() >= 50) return v; // treat as cm
    return metersToCm(v);
  }
}
