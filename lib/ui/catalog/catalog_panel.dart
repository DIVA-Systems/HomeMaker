import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_settings.dart';
import '../../models/catalog_item.dart';
import '../../models/floor_plan.dart';
import '../../state/providers.dart';
import '../../theme/hm_colors.dart';
import '../../units/length_units.dart';
import 'catalog_icon.dart';
import 'import_furniture_sheet.dart';

class CatalogPanel extends ConsumerWidget {
  const CatalogPanel({
    super.key,
    required this.planSeed,
    this.compact = false,
  });

  final FloorPlan planSeed;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(editorProvider(planSeed));
    final catalogAsync = ref.watch(catalogProvider);
    final notifier = ref.read(editorProvider(planSeed).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(compact ? 16 : 20, 12, compact ? 16 : 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Furniture',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => showImportFurnitureSheet(context, ref),
                    child: const Icon(CupertinoIcons.plus_circle, size: 26),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Free SH3D models · drag onto plan · + to import',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              CupertinoSearchTextField(
                placeholder: 'Search chairs, beds, lamps…',
                onChanged: notifier.setSearch,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final cat in CatalogCategory.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat.label),
                          selected: editor.category == cat,
                          onSelected: (_) => notifier.setCategory(cat),
                          selectedColor: HmColors.spruce.withValues(alpha: 0.18),
                          labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: editor.category == cat
                                    ? HmColors.spruce
                                    : HmColors.inkSecondary,
                              ),
                          side: BorderSide(
                            color: editor.category == cat
                                ? HmColors.spruce.withValues(alpha: 0.4)
                                : HmColors.hairline,
                          ),
                          backgroundColor: Colors.transparent,
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: catalogAsync.when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (e, _) => Center(child: Text('Couldn’t load catalog\n$e')),
            data: (items) {
              final q = editor.searchQuery.trim().toLowerCase();
              final key = editor.category.jsonKey;
              final filtered = items.where((i) {
                if (key != null && i.category != key) return false;
                if (q.isEmpty) return true;
                return i.name.toLowerCase().contains(q) ||
                    i.categoryLabel.toLowerCase().contains(q);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'No pieces match',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: HmColors.inkSecondary,
                        ),
                  ),
                );
              }

              return GridView.builder(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 16,
                  4,
                  compact ? 12 : 16,
                  24,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: compact ? 3 : 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.78,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final selected = editor.placingCatalogId == item.id;
                  return LongPressDraggable<String>(
                    data: item.id,
                    delay: const Duration(milliseconds: 180),
                    feedback: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 96,
                        height: 96,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: CatalogIcon(item: item),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.35,
                      child: _CatalogTile(
                        item: item,
                        selected: selected,
                        unitSystem:
                            ref.watch(appSettingsProvider).unitSystem,
                        onTap: () => notifier.beginPlacing(item.id),
                      ),
                    ),
                    child: _CatalogTile(
                      item: item,
                      selected: selected,
                      unitSystem: ref.watch(appSettingsProvider).unitSystem,
                      onTap: () => notifier.beginPlacing(item.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.unitSystem,
  });

  final CatalogItem item;
  final bool selected;
  final VoidCallback onTap;
  final LengthUnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.name}, ${item.categoryLabel}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: selected
                  ? HmColors.spruce.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? HmColors.spruce : HmColors.hairline,
                width: selected ? 1.6 : 1,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ColoredBox(
                      color: HmColors.canvas.withValues(alpha: 0.65),
                      child: CatalogIcon(item: item),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  Units.formatSize2d(item.widthCm, item.depthCm, unitSystem),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
