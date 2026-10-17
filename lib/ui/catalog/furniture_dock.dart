import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/catalog_item.dart';
import '../../models/floor_plan.dart';
import '../../state/providers.dart';
import '../../theme/hm_colors.dart';
import 'catalog_panel.dart';

/// Always-visible furniture strip for phones (SH3D-style catalog access).
class FurnitureDock extends ConsumerWidget {
  const FurnitureDock({super.key, required this.planSeed});

  final FloorPlan planSeed;

  void _openFullCatalog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.82,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: HmColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: CatalogPanel(planSeed: planSeed, compact: true),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(editorProvider(planSeed));
    final catalogAsync = ref.watch(catalogProvider);
    final notifier = ref.read(editorProvider(planSeed).notifier);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
            child: Row(
              children: [
                Text('Furniture', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final cat in CatalogCategory.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(cat.label),
                              selected: editor.category == cat,
                              onSelected: (_) => notifier.setCategory(cat),
                              selectedColor: HmColors.spruce.withValues(alpha: 0.16),
                              showCheckmark: false,
                              visualDensity: VisualDensity.compact,
                              labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: editor.category == cat
                                        ? HmColors.spruce
                                        : HmColors.inkSecondary,
                                  ),
                              side: BorderSide(
                                color: editor.category == cat
                                    ? HmColors.spruce.withValues(alpha: 0.35)
                                    : HmColors.hairline,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: () => _openFullCatalog(context),
                  child: Text(
                    'All',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: HmColors.spruceSoft,
                        ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 108,
            child: catalogAsync.when(
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (items) {
                final key = editor.category.jsonKey;
                final filtered = items
                    .where((i) => key == null || i.category == key)
                    .toList();
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    final selected = editor.placingCatalogId == item.id;
                    return _DockTile(
                      item: item,
                      selected: selected,
                      onTap: () => notifier.beginPlacing(item.id),
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(height: bottomInset > 0 ? bottomInset : 6),
        ],
      ),
    );
  }
}

class _DockTile extends StatelessWidget {
  const _DockTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final CatalogItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 88,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? HmColors.spruce.withValues(alpha: 0.12)
                : HmColors.canvas.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? HmColors.spruce : HmColors.hairline,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Image.asset(
                  item.iconPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.weekend_outlined, size: 28),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
