import 'package:shared_preferences/shared_preferences.dart';

import '../models/floor_plan.dart';

class PlanStorage {
  static const _indexKey = 'hm.plans.index';
  static const _planPrefix = 'hm.plan.';
  static const _seenWelcomeKey = 'hm.seenWelcome';

  Future<bool> hasSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenWelcomeKey) ?? false;
  }

  Future<void> setSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenWelcomeKey, true);
  }

  Future<List<FloorPlan>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_indexKey) ?? [];
    final plans = <FloorPlan>[];
    for (final id in ids) {
      final raw = prefs.getString('$_planPrefix$id');
      if (raw == null) continue;
      try {
        plans.add(FloorPlan.decode(raw));
      } catch (_) {
        // skip corrupt
      }
    }
    plans.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return plans;
  }

  Future<void> save(FloorPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    plan.updatedAt = DateTime.now();
    await prefs.setString('$_planPrefix${plan.id}', plan.encode());
    final ids = prefs.getStringList(_indexKey) ?? [];
    if (!ids.contains(plan.id)) {
      ids.insert(0, plan.id);
      await prefs.setStringList(_indexKey, ids);
    }
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_planPrefix$id');
    final ids = prefs.getStringList(_indexKey) ?? [];
    ids.remove(id);
    await prefs.setStringList(_indexKey, ids);
  }
}
