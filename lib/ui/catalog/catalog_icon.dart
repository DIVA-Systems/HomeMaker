import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/catalog_item.dart';
import '../../state/providers.dart';
import '../../theme/hm_colors.dart';

class CatalogIcon extends ConsumerWidget {
  const CatalogIcon({
    super.key,
    required this.item,
    this.fit = BoxFit.contain,
  });

  final CatalogItem item;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!item.isUserImport) {
      return Image.asset(
        item.iconPath,
        fit: fit,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.weekend_outlined,
          color: HmColors.inkTertiary,
        ),
      );
    }
    return FutureBuilder<File?>(
      future: ref
          .read(catalogRepositoryProvider)
          .userStore
          .resolveIconFile(item),
      builder: (context, snap) {
        final f = snap.data;
        if (f == null) {
          return const Icon(Icons.image_outlined, color: HmColors.inkTertiary);
        }
        return Image.file(f, fit: fit);
      },
    );
  }
}
