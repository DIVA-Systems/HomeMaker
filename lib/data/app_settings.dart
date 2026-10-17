import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../units/length_units.dart';

class AppSettings {
  const AppSettings({
    this.unitSystem = LengthUnitSystem.metric,
    this.magnetism = true,
    this.showDimensions = true,
    this.lightIntensity = 0.85,
    this.ambientLight = 0.35,
  });

  final LengthUnitSystem unitSystem;
  final bool magnetism;
  final bool showDimensions;
  final double lightIntensity; // 0..1 directional
  final double ambientLight; // 0..1

  AppSettings copyWith({
    LengthUnitSystem? unitSystem,
    bool? magnetism,
    bool? showDimensions,
    double? lightIntensity,
    double? ambientLight,
  }) {
    return AppSettings(
      unitSystem: unitSystem ?? this.unitSystem,
      magnetism: magnetism ?? this.magnetism,
      showDimensions: showDimensions ?? this.showDimensions,
      lightIntensity: lightIntensity ?? this.lightIntensity,
      ambientLight: ambientLight ?? this.ambientLight,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  static const _kUnits = 'hm.settings.units';
  static const _kMagnet = 'hm.settings.magnetism';
  static const _kDims = 'hm.settings.dimensions';
  static const _kLight = 'hm.settings.light';
  static const _kAmbient = 'hm.settings.ambient';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final units = p.getString(_kUnits);
    state = AppSettings(
      unitSystem: units == 'imperial'
          ? LengthUnitSystem.imperial
          : LengthUnitSystem.metric,
      magnetism: p.getBool(_kMagnet) ?? true,
      showDimensions: p.getBool(_kDims) ?? true,
      lightIntensity: p.getDouble(_kLight) ?? 0.85,
      ambientLight: p.getDouble(_kAmbient) ?? 0.35,
    );
  }

  Future<void> setUnitSystem(LengthUnitSystem system) async {
    state = state.copyWith(unitSystem: system);
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kUnits,
      system == LengthUnitSystem.imperial ? 'imperial' : 'metric',
    );
  }

  Future<void> setMagnetism(bool value) async {
    state = state.copyWith(magnetism: value);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kMagnet, value);
  }

  Future<void> setShowDimensions(bool value) async {
    state = state.copyWith(showDimensions: value);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDims, value);
  }

  Future<void> setLightIntensity(double value) async {
    state = state.copyWith(lightIntensity: value.clamp(0.0, 1.0));
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kLight, state.lightIntensity);
  }

  Future<void> setAmbientLight(double value) async {
    state = state.copyWith(ambientLight: value.clamp(0.0, 1.0));
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kAmbient, state.ambientLight);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (ref) => AppSettingsNotifier(),
);
