import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/floor_plan.dart';
import '../../state/providers.dart';
import '../../theme/hm_colors.dart';
import '../catalog/catalog_panel.dart';
import '../catalog/furniture_dock.dart';
import '../preview/preview_3d_screen.dart';
import 'editor_toolbar.dart';
import 'plan_canvas.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, required this.plan});

  final FloorPlan plan;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  int _fitNonce = 0;
  Size? _lastSize;

  void _bumpFit() => setState(() => _fitNonce++);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    if (_lastSize != size) {
      _lastSize = size;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bumpFit();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 700;

    return Scaffold(
      body: isTablet
          ? _TabletEditor(
              plan: widget.plan,
              fitNonce: _fitNonce,
              onFitView: _bumpFit,
            )
          : _PhoneEditor(
              plan: widget.plan,
              fitNonce: _fitNonce,
              onFitView: _bumpFit,
            ),
    );
  }
}

class _TabletEditor extends ConsumerWidget {
  const _TabletEditor({
    required this.plan,
    required this.fitNonce,
    required this.onFitView,
  });
  final FloorPlan plan;
  final int fitNonce;
  final VoidCallback onFitView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorProvider(plan));

    return Row(
      children: [
        SizedBox(
          width: MediaQuery.sizeOf(context).width >= 1000 ? 360 : 300,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              right: false,
              child: CatalogPanel(planSeed: plan),
            ),
          ),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: HmColors.hairline.withValues(alpha: 0.8),
        ),
        Expanded(
          child: Column(
            children: [
              EditorToolbar(
                planSeed: plan,
                onFitView: onFitView,
                onOpenPreview: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => Preview3dScreen(plan: state.plan),
                    ),
                  );
                },
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: PlanCanvas(planSeed: plan, fitNonce: fitNonce),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 20,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.tool == EditorTool.place &&
                              state.placingCatalogId != null)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: _HintBar(
                                text:
                                    'Tap plan to place · drag empty area to pan · pinch to zoom',
                              ),
                            ),
                          if (state.tool == EditorTool.wall)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _HintBar(
                                text: state.wallChainFrom != null
                                    ? 'Walls chain from the green point · long-press breaks chain'
                                    : 'Drag to draw walls · ends snap together',
                              ),
                            ),
                          if (state.tool == EditorTool.door)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: _HintBar(text: 'Tap a wall to place a door'),
                            ),
                          if (state.tool == EditorTool.window)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child:
                                  _HintBar(text: 'Tap a wall to place a window'),
                            ),
                          if (state.tool == EditorTool.select)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: _HintBar(
                                text:
                                    'Pan · move furniture · drag rotate handle when selected',
                              ),
                            ),
                          Center(child: EditorToolRail(planSeed: plan)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhoneEditor extends ConsumerWidget {
  const _PhoneEditor({
    required this.plan,
    required this.fitNonce,
    required this.onFitView,
  });
  final FloorPlan plan;
  final int fitNonce;
  final VoidCallback onFitView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorProvider(plan));

    return Column(
      children: [
        EditorToolbar(
          planSeed: plan,
          showCatalogButton: false,
          onFitView: onFitView,
          onOpenPreview: () {
            Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (_) => Preview3dScreen(plan: state.plan),
              ),
            );
          },
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: PlanCanvas(planSeed: plan, fitNonce: fitNonce),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _HintBar(
                        text: _hintFor(state),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(child: EditorToolRail(planSeed: plan)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Always-visible furniture — was the portrait “missing catalog” bug.
        FurnitureDock(planSeed: plan),
      ],
    );
  }

  String _hintFor(EditorState state) {
    switch (state.tool) {
      case EditorTool.wall:
        return state.wallChainFrom != null
            ? 'Next wall chains from the green point · long-press to break'
            : 'Drag to draw walls · ends snap & chain';
      case EditorTool.door:
        return 'Tap a wall to insert a door';
      case EditorTool.window:
        return 'Tap a wall to insert a window';
      case EditorTool.place:
        return state.placingCatalogId == null
            ? 'Pick furniture below, then tap the plan'
            : 'Tap plan to place · swipe dock for more';
      case EditorTool.erase:
        return 'Tap a wall, opening, or piece to remove';
      case EditorTool.select:
        return 'Pan · pinch zoom · drag items · use rotate handle';
    }
  }
}

class _HintBar extends StatelessWidget {
  const _HintBar({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HmColors.spruce.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: HmColors.inkOnAccent,
                ),
          ),
        ),
      ),
    );
  }
}
