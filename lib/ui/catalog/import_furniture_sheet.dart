import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/app_settings.dart';
import '../../models/catalog_item.dart';
import '../../state/providers.dart';
import '../../theme/hm_colors.dart';
import '../../units/length_units.dart';

Future<void> showImportFurnitureSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _ImportFurnitureSheet(),
  );
}

class _ImportFurnitureSheet extends ConsumerStatefulWidget {
  const _ImportFurnitureSheet();

  @override
  ConsumerState<_ImportFurnitureSheet> createState() =>
      _ImportFurnitureSheetState();
}

class _ImportFurnitureSheetState extends ConsumerState<_ImportFurnitureSheet> {
  File? _image;
  final _name = TextEditingController(text: 'Custom piece');
  CatalogCategory _cat = CatalogCategory.livingRoom;
  double _w = 80;
  double _d = 80;
  double _h = 80;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    setState(() => _image = File(x.path));
  }

  Future<void> _save() async {
    if (_image == null) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(catalogRepositoryProvider);
      await repo.userStore.importFromImage(
        imageFile: _image!,
        name: _name.text.trim().isEmpty ? 'Custom piece' : _name.text.trim(),
        category: _cat.jsonKey ?? 'livingRoom',
        widthCm: _w,
        depthCm: _d,
        heightCm: _h,
      );
      await repo.invalidate();
      ref.invalidate(catalogProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(appSettingsProvider).unitSystem;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: HmColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Import furniture', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Pick a photo or top-down drawing — like Sweet Home 3D import.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.4,
              child: Material(
                color: HmColors.canvas.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _pick,
                  borderRadius: BorderRadius.circular(14),
                  child: _image == null
                      ? const Center(child: Text('Tap to choose image'))
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(_image!, fit: BoxFit.contain),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final c in CatalogCategory.values.where(
                  (c) => c != CatalogCategory.all,
                ))
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _cat == c,
                    onSelected: (_) => setState(() => _cat = c),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Width ${Units.formatLength(_w, units)}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Slider(
              value: _w,
              min: 20,
              max: 300,
              onChanged: (v) => setState(() => _w = v),
            ),
            Text(
              'Depth ${Units.formatLength(_d, units)}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Slider(
              value: _d,
              min: 20,
              max: 300,
              onChanged: (v) => setState(() => _d = v),
            ),
            Text(
              'Height ${Units.formatLength(_h, units)}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Slider(
              value: _h,
              min: 10,
              max: 300,
              onChanged: (v) => setState(() => _h = v),
            ),
            const SizedBox(height: 8),
            CupertinoButton.filled(
              onPressed: _busy || _image == null ? null : _save,
              child: _busy
                  ? const CupertinoActivityIndicator()
                  : const Text('Add to catalog'),
            ),
          ],
        ),
      ),
    );
  }
}
