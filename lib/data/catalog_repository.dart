import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/catalog_item.dart';

class CatalogRepository {
  CatalogRepository();

  List<CatalogItem>? _cache;

  Future<List<CatalogItem>> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/catalog/catalog.json');
    final list = jsonDecode(raw) as List<dynamic>;
    _cache = list
        .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return _cache!;
  }

  CatalogItem? byId(String id) {
    final cache = _cache;
    if (cache == null) return null;
    for (final item in cache) {
      if (item.id == id) return item;
    }
    return null;
  }
}
