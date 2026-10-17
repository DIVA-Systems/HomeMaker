import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/floor_plan.dart';
import '../../state/providers.dart';
import '../common/glass_surface.dart';
import '../common/hm_buttons.dart';

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
