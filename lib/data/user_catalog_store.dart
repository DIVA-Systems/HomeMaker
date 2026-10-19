import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/catalog_item.dart';

const _uuid = Uuid();
const _prefsKey = 'hm.userCatalog';

/// User-imported furniture (image + dimensions) — SH3D "Import furniture".
class UserCatalogStore {
  Future<Directory> _dir() async {
    final root = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(root.path, 'user_catalog'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<List<CatalogItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    final out = <CatalogItem>[];
    for (final s in raw) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        out.add(CatalogItem.fromJson(m));
      } catch (_) {}
    }
    return out;
  }

  Future<CatalogItem> importFromImage({
    required File imageFile,
    required String name,
    required String category,
    required double widthCm,
    required double depthCm,
    required double heightCm,
  }) async {
    final dir = await _dir();
    final id = 'user_${_uuid.v4()}';
    final ext = p.extension(imageFile.path).isEmpty
        ? '.png'
        : p.extension(imageFile.path);
    final destName = '$id$ext';
    final dest = File(p.join(dir.path, destName));
    await imageFile.copy(dest.path);

    final item = CatalogItem(
      id: id,
      name: name,
      category: category,
      license: 'User import',
      attribution: 'Imported by user',
      widthCm: widthCm,
      depthCm: depthCm,
      heightCm: heightCm,
      iconAsset: 'user:$destName',
      modelAsset: '',
      sourceLibrary: 'user',
      creator: 'You',
    );

    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? [];
    list.add(jsonEncode({
      'id': item.id,
      'name': item.name,
      'category': item.category,
      'license': item.license,
      'attribution': item.attribution,
      'widthCm': item.widthCm,
      'depthCm': item.depthCm,
      'heightCm': item.heightCm,
      'iconAsset': item.iconAsset,
      'modelAsset': item.modelAsset,
      'sourceLibrary': item.sourceLibrary,
      'creator': item.creator,
    }));
    await prefs.setStringList(_prefsKey, list);
    return item;
  }

  Future<File?> resolveIconFile(CatalogItem item) async {
    if (!item.iconAsset.startsWith('user:')) return null;
    final name = item.iconAsset.substring(5);
    final dir = await _dir();
    final f = File(p.join(dir.path, name));
    return f.existsSync() ? f : null;
  }
}
