import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/catalog_item.dart';
import 'user_catalog_store.dart';

class CatalogRepository {
  CatalogRepository({UserCatalogStore? userStore})
      : _userStore = userStore ?? UserCatalogStore();

  final UserCatalogStore _userStore;
  List<CatalogItem>? _cache;

  Future<List<CatalogItem>> load({bool force = false}) async {
    if (_cache != null && !force) return _cache!;
    final raw = await rootBundle.loadString('assets/catalog/catalog.json');
    final list = jsonDecode(raw) as List<dynamic>;
    final builtIn = list
        .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final user = await _userStore.load();
    _cache = [...builtIn, ...user]
      ..sort((a, b) => a.name.compareTo(b.name));
    return _cache!;
  }

  Future<void> invalidate() async {
    _cache = null;
  }

  UserCatalogStore get userStore => _userStore;

  CatalogItem? byId(String id) {
    final cache = _cache;
    if (cache == null) return null;
    for (final item in cache) {
      if (item.id == id) return item;
    }
    return null;
  }
}
