import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_settings.dart';
import '../../theme/hm_colors.dart';
import '../../units/length_units.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text('Units', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Used for walls, rooms, catalog furniture sizes, and the scale bar. '
            'You can also toggle m/ft from the plan toolbar.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SegmentedButton<LengthUnitSystem>(
            segments: const [
              ButtonSegment(
                value: LengthUnitSystem.metric,
                label: Text('Meters'),
                icon: Icon(Icons.straighten, size: 18),
              ),
              ButtonSegment(
                value: LengthUnitSystem.imperial,
                label: Text('Feet'),
                icon: Icon(Icons.square_foot, size: 18),
              ),
            ],
            selected: {settings.unitSystem},
            onSelectionChanged: (s) => notifier.setUnitSystem(s.first),
          ),
          const SizedBox(height: 8),
          Text(
            settings.unitSystem == LengthUnitSystem.metric
                ? 'Furniture example: ${Units.formatSize2d(220, 90, LengthUnitSystem.metric)}'
                : 'Furniture example: ${Units.formatSize2d(220, 90, LengthUnitSystem.imperial)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: HmColors.spruceSoft,
                ),
          ),
          const SizedBox(height: 28),
          Text('Plan editor', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Magnetism'),
            subtitle: const Text('Snap wall ends and chain corners'),
            value: settings.magnetism,
            activeTrackColor: HmColors.spruce,
            onChanged: notifier.setMagnetism,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show dimensions'),
            subtitle: const Text('Length labels on walls'),
            value: settings.showDimensions,
            activeTrackColor: HmColors.spruce,
            onChanged: notifier.setShowDimensions,
          ),
          const SizedBox(height: 20),
          Text('3D lighting', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Sun / key light', style: Theme.of(context).textTheme.bodySmall),
          Slider(
            value: settings.lightIntensity,
            onChanged: notifier.setLightIntensity,
            activeColor: HmColors.spruce,
          ),
          Text('Ambient fill', style: Theme.of(context).textTheme.bodySmall),
          Slider(
            value: settings.ambientLight,
            onChanged: notifier.setAmbientLight,
            activeColor: HmColors.spruceSoft,
          ),
          const SizedBox(height: 24),
          Text(
            'Furniture models © Sweet Home 3D free libraries — see attributions in the catalog.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
