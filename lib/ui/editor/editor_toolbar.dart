import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_settings.dart';
import '../../data/plan_io.dart';
import '../../models/catalog_item.dart';
import '../../models/floor_plan.dart';
import '../../state/providers.dart';
import '../../theme/hm_colors.dart';
import '../../units/length_units.dart';
import '../common/glass_surface.dart';
import '../common/hm_buttons.dart';
import '../overlay/overlay_wizard_screen.dart';

const _materialSwatches = <int?>[
  null,
  0xFFE8E2D6,
  0xFFC4B5A0,
  0xFF8B7355,
  0xFF5C6B5A,
  0xFF3D5A80,
  0xFFB85C38,
  0xFF2A2E2C,
  0xFFD4A574,
];

class EditorToolbar extends ConsumerWidget {
  const EditorToolbar({
    super.key,
    required this.planSeed,
    this.onOpenCatalog,
    this.onOpenPreview,
    this.onFitView,
    this.showCatalogButton = false,
  });

  final FloorPlan planSeed;
  final VoidCallback? onOpenCatalog;
  final VoidCallback? onOpenPreview;
  final VoidCallback? onFitView;
  final bool showCatalogButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorProvider(planSeed));
    final notifier = ref.read(editorProvider(planSeed).notifier);
    final settings = ref.watch(appSettingsProvider);
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    final level = state.plan.activeLevel;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            GlassSurface(
              borderRadius: 14,
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: () async {
                      if (state.dirty) await notifier.save();
                      if (context.mounted) Navigator.of(context).maybePop();
                    },
                    child: const Icon(CupertinoIcons.back, size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GlassSurface(
                borderRadius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${level.name} · ${state.dirty ? 'Unsaved' : 'Saved'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GlassSurface(
              borderRadius: 14,
              padding: const EdgeInsets.all(4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HmIconChip(
                      icon: Icons.undo_rounded,
                      selected: false,
                      tooltip: 'Undo',
                      enabled: state.canUndo,
                      onTap: notifier.undo,
                    ),
                    HmIconChip(
                      icon: Icons.redo_rounded,
                      selected: false,
                      tooltip: 'Redo',
                      enabled: state.canRedo,
                      onTap: notifier.redo,
                    ),
                    HmIconChip(
                      icon: Icons.layers_outlined,
                      selected: false,
                      tooltip: 'Levels',
                      onTap: () => _showLevels(context, state, notifier),
                    ),
                    HmIconChip(
                      icon: Icons.image_outlined,
                      selected: state.plan.overlay?.visible == true,
                      tooltip: 'Floor plan overlay',
                      onTap: () => _showOverlayMenu(
                        context,
                        state,
                        notifier,
                      ),
                    ),
                    HmIconChip(
                      icon: settings.unitSystem == LengthUnitSystem.metric
                          ? Icons.straighten
                          : Icons.square_foot,
                      selected: false,
                      tooltip: settings.unitSystem == LengthUnitSystem.metric
                          ? 'Units: meters (tap for feet)'
                          : 'Units: feet (tap for meters)',
                      onTap: () => settingsNotifier.setUnitSystem(
                        settings.unitSystem == LengthUnitSystem.metric
                            ? LengthUnitSystem.imperial
                            : LengthUnitSystem.metric,
                      ),
                    ),
                    if (showCatalogButton)
                      HmIconChip(
                        icon: Icons.chair_outlined,
                        selected: false,
                        tooltip: 'Furniture',
                        onTap: onOpenCatalog ?? () {},
                      ),
                    HmIconChip(
                      icon: Icons.fit_screen_outlined,
                      selected: false,
                      tooltip: 'Fit plan',
                      onTap: onFitView ?? () {},
                    ),
                    HmIconChip(
                      icon: Icons.threed_rotation,
                      selected: false,
                      tooltip: '3D view',
                      onTap: onOpenPreview ?? () {},
                    ),
                    HmIconChip(
                      icon: Icons.ios_share,
                      selected: false,
                      tooltip: 'Export',
                      onTap: () => _showExport(
                        context,
                        ref,
                        state,
                        settings.unitSystem,
                      ),
                    ),
                    HmIconChip(
                      icon: Icons.rotate_right,
                      selected: false,
                      tooltip: 'Rotate 15°',
                      onTap: () => notifier.rotateSelected(),
                    ),
                    if (state.selectedFurnitureId != null &&
                        state.plan.furniture
                            .any((f) => f.id == state.selectedFurnitureId)) ...[
                      HmIconChip(
                        icon: Icons.vertical_align_top,
                        selected: false,
                        tooltip: 'Raise elevation +5 cm',
                        onTap: () => notifier.nudgeSelectedElevation(5),
                      ),
                      HmIconChip(
                        icon: Icons.vertical_align_bottom,
                        selected: false,
                        tooltip: 'Lower elevation −5 cm',
                        onTap: () => notifier.nudgeSelectedElevation(-5),
                      ),
                      HmIconChip(
                        icon: Icons.palette_outlined,
                        selected: false,
                        tooltip: 'Material color',
                        onTap: () => _showMaterials(context, state, notifier),
                      ),
                    ],
                    HmIconChip(
                      icon: CupertinoIcons.trash,
                      selected: false,
                      tooltip: 'Delete',
                      onTap: notifier.removeSelected,
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      onPressed: state.dirty ? () => notifier.save() : null,
                      child: Text(
                        'Save',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: state.dirty
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).textTheme.bodySmall?.color,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExport(
    BuildContext context,
    WidgetRef ref,
    EditorState state,
    LengthUnitSystem units,
  ) async {
    final catalog =
        ref.read(catalogProvider).valueOrNull ?? const <CatalogItem>[];
    final map = {for (final c in catalog) c.id: c};
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Export'),
        message: const Text(
          'Share a plan file, floor-plan image, or open 3D for photo/video.',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              await PlanIo.exportHmplan(state.plan);
            },
            child: const Text('Share .hmplan file'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              await PlanIo.exportPlanPng(
                plan: state.plan,
                catalog: map,
                unitSystem: units,
                isDark: isDark,
              );
            },
            child: const Text('Export floor plan PNG'),
          ),
          if (onOpenPreview != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                onOpenPreview!();
              },
              child: const Text('3D photo / turntable…'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showMaterials(
    BuildContext context,
    EditorState state,
    EditorNotifier notifier,
  ) {
    final id = state.selectedFurnitureId;
    if (id == null) return;
    final idx = state.plan.furniture.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    final current = state.plan.furniture[idx].colorArgb;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Material color',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tint the selected piece (plan + 3D)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final swatch in _materialSwatches)
                      GestureDetector(
                        onTap: () {
                          notifier.setSelectedMaterialColor(swatch);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: swatch == null
                                ? HmColors.canvas
                                : Color(swatch),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: current == swatch
                                  ? HmColors.spruce
                                  : HmColors.hairline,
                              width: current == swatch ? 2.5 : 1,
                            ),
                          ),
                          child: swatch == null
                              ? const Icon(Icons.block, size: 18)
                              : null,
                        ),
                      ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: CupertinoButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOverlayMenu(
    BuildContext context,
    EditorState state,
    EditorNotifier notifier,
  ) {
    final has = state.plan.overlay != null;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Floor plan overlay'),
        message: const Text(
          'Import a photo or scan — scale it, then draw walls on top '
          '(Sweet Home 3D Background Image).',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => OverlayWizardScreen(planSeed: planSeed),
                ),
              );
            },
            child: Text(has ? 'Replace image…' : 'Import image…'),
          ),
          if (has) ...[
            CupertinoActionSheetAction(
              onPressed: () {
                final vis = state.plan.overlay?.visible ?? true;
                notifier.setOverlayVisible(!vis);
                Navigator.pop(ctx);
              },
              child: Text(
                (state.plan.overlay?.visible ?? true) ? 'Hide overlay' : 'Show overlay',
              ),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                notifier.clearOverlay();
                Navigator.pop(ctx);
              },
              child: const Text('Remove overlay'),
            ),
          ],
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showLevels(
    BuildContext context,
    EditorState state,
    EditorNotifier notifier,
  ) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Levels'),
        message: const Text('Switch floors or add an upper level'),
        actions: [
          for (var i = 0; i < state.plan.levels.length; i++)
            CupertinoActionSheetAction(
              onPressed: () {
                notifier.setActiveLevel(i);
                Navigator.pop(ctx);
              },
              child: Text(
                state.plan.levels[i].name +
                    (i == state.plan.activeLevelIndex ? '  ✓' : ''),
              ),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              notifier.addLevel();
              Navigator.pop(ctx);
            },
            child: const Text('Add level'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

class EditorToolRail extends ConsumerWidget {
  const EditorToolRail({super.key, required this.planSeed});

  final FloorPlan planSeed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorProvider(planSeed));
    final notifier = ref.read(editorProvider(planSeed).notifier);

    return GlassSurface(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HmIconChip(
              icon: CupertinoIcons.hand_draw,
              selected: state.tool == EditorTool.select,
              tooltip: 'Select',
              onTap: () => notifier.setTool(EditorTool.select),
            ),
            HmIconChip(
              icon: Icons.border_color_outlined,
              selected: state.tool == EditorTool.wall,
              tooltip: 'Draw wall',
              onTap: () => notifier.setTool(EditorTool.wall),
            ),
            HmIconChip(
              icon: Icons.door_front_door_outlined,
              selected: state.tool == EditorTool.door,
              tooltip: 'Door',
              onTap: () => notifier.setTool(EditorTool.door),
            ),
            HmIconChip(
              icon: Icons.window_outlined,
              selected: state.tool == EditorTool.window,
              tooltip: 'Window',
              onTap: () => notifier.setTool(EditorTool.window),
            ),
            HmIconChip(
              icon: Icons.stairs,
              selected: state.tool == EditorTool.stair,
              tooltip: 'Stairs',
              onTap: () => notifier.setTool(EditorTool.stair),
            ),
            HmIconChip(
              icon: Icons.weekend_outlined,
              selected: state.tool == EditorTool.place,
              tooltip: 'Place furniture',
              onTap: () => notifier.setTool(EditorTool.place),
            ),
            HmIconChip(
              icon: CupertinoIcons.scissors,
              selected: state.tool == EditorTool.erase,
              tooltip: 'Erase',
              onTap: () => notifier.setTool(EditorTool.erase),
            ),
          ],
        ),
      ),
    );
  }
}
