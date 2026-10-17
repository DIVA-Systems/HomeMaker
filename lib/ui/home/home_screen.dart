import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/floor_plan.dart';
import '../../state/providers.dart';
import '../../theme/hm_colors.dart';
import '../common/hm_buttons.dart';
import '../editor/editor_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _newPlan(BuildContext context, WidgetRef ref, {bool starter = true}) async {
    final storage = ref.read(planStorageProvider);
    final plan = starter ? FloorPlan.starter() : FloorPlan.blank();
    await storage.save(plan);
    ref.invalidate(plansProvider);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => EditorScreen(plan: plan)),
    );
    ref.invalidate(plansProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansProvider);
    final catalogAsync = ref.watch(catalogProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 700;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: isWide ? 168 : 148,
            title: const Text('HomeMaker'),
            actions: [
              CupertinoButton(
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
                child: const Icon(CupertinoIcons.settings),
              ),
              CupertinoButton(
                onPressed: () => _showAbout(context, catalogAsync.valueOrNull?.length ?? 0),
                child: const Icon(CupertinoIcons.info),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroHeader(isWide: isWide),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(isWide ? 28 : 20, 8, isWide ? 28 : 20, 12),
              child: Row(
                children: [
                  HmPrimaryButton(
                    label: 'New room',
                    icon: CupertinoIcons.plus,
                    onPressed: () => _newPlan(context, ref),
                  ),
                  const SizedBox(width: 8),
                  HmGhostButton(
                    label: 'Blank plan',
                    onPressed: () => _newPlan(context, ref, starter: false),
                  ),
                ],
              ),
            ),
          ),
          plansAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Couldn’t load plans\n$e')),
            ),
            data: (plans) {
              if (plans.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyHome(onCreate: () => _newPlan(context, ref)),
                );
              }
              return SliverPadding(
                padding: EdgeInsets.fromLTRB(isWide ? 28 : 20, 0, isWide ? 28 : 20, 40),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWide ? 3 : 1,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: isWide ? 1.35 : 2.4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final plan = plans[i];
                      return _PlanCard(
                        plan: plan,
                        onOpen: () async {
                          await Navigator.of(context).push(
                            CupertinoPageRoute<void>(
                              builder: (_) => EditorScreen(plan: plan),
                            ),
                          );
                          ref.invalidate(plansProvider);
                        },
                        onDelete: () async {
                          await ref.read(planStorageProvider).delete(plan.id);
                          ref.invalidate(plansProvider);
                        },
                      );
                    },
                    childCount: plans.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context, int count) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('HomeMaker'),
        content: Text(
          'Design rooms with $count free furniture models from Sweet Home 3D '
          '(Free Art, CC-BY, CC0). Attribution lives in Settings-bound credits.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.isWide});
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE7EFEA),
            Color(0xFFF3EFE7),
            Color(0xFFE8DFD2),
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.fromLTRB(isWide ? 28 : 20, 0, 20, 56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HomeMaker',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Sketch walls. Place furniture. See it in 3D.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: HmColors.inkSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.home_work_outlined, size: 56, color: HmColors.spruceSoft),
          const SizedBox(height: 16),
          Text('No plans yet', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Start with a simple room, then furnish it from the catalog.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: HmColors.inkSecondary,
                ),
          ),
          const SizedBox(height: 24),
          HmPrimaryButton(
            label: 'Create your first room',
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.onOpen,
    required this.onDelete,
  });

  final FloorPlan plan;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final updated = plan.updatedAt;
    final label =
        '${updated.year}-${updated.month.toString().padLeft(2, '0')}-${updated.day.toString().padLeft(2, '0')}';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: HmColors.hairline),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF7F4EE), Color(0xFFECE6DA)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(plan.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        '${plan.walls.length} walls · ${plan.furniture.length} pieces',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text('Updated $label', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.all(8),
                  onPressed: () => _confirmDelete(context),
                  child: const Icon(CupertinoIcons.delete, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete plan?'),
        content: Text('“${plan.name}” will be removed from this device.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
