import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/catalog_repository.dart';
import '../data/plan_storage.dart';
import '../geometry/room_detection.dart';
import '../models/catalog_item.dart';
import '../models/floor_plan.dart';

const _uuid = Uuid();

final catalogRepositoryProvider = Provider((ref) => CatalogRepository());
final planStorageProvider = Provider((ref) => PlanStorage());

final catalogProvider = FutureProvider<List<CatalogItem>>((ref) async {
  return ref.watch(catalogRepositoryProvider).load();
});

final catalogByIdProvider = Provider.family<CatalogItem?, String>((ref, id) {
  final async = ref.watch(catalogProvider);
  return async.maybeWhen(
    data: (items) {
      for (final i in items) {
        if (i.id == id) return i;
      }
      return null;
    },
    orElse: () => null,
  );
});

final plansProvider = FutureProvider<List<FloorPlan>>((ref) async {
  return ref.watch(planStorageProvider).loadAll();
});

final welcomeSeenProvider = FutureProvider<bool>((ref) async {
  return ref.watch(planStorageProvider).hasSeenWelcome();
});

enum EditorTool {
  select,
  wall,
  door,
  window,
  stair,
  place,
  erase,
}

class EditorState {
  const EditorState({
    required this.plan,
    this.tool = EditorTool.select,
    this.selectedWallId,
    this.selectedFurnitureId,
    this.selectedOpeningId,
    this.placingCatalogId,
    this.category = CatalogCategory.all,
    this.searchQuery = '',
    this.dirty = false,
    this.canUndo = false,
    this.canRedo = false,
    this.wallChainFrom,
    this.detectedRooms = const [],
  });

  final FloorPlan plan;
  final EditorTool tool;
  final String? selectedWallId;
  final String? selectedFurnitureId;
  final String? selectedOpeningId;
  final String? placingCatalogId;
  final CatalogCategory category;
  final String searchQuery;
  final bool dirty;
  final bool canUndo;
  final bool canRedo;
  /// When set, next wall starts from this point (SH3D chaining).
  final Offset? wallChainFrom;
  final List<PlanRoom> detectedRooms;

  EditorState copyWith({
    FloorPlan? plan,
    EditorTool? tool,
    String? selectedWallId,
    String? selectedFurnitureId,
    String? selectedOpeningId,
    String? placingCatalogId,
    CatalogCategory? category,
    String? searchQuery,
    bool? dirty,
    bool? canUndo,
    bool? canRedo,
    Offset? wallChainFrom,
    List<PlanRoom>? detectedRooms,
    bool clearWall = false,
    bool clearFurniture = false,
    bool clearOpening = false,
    bool clearPlacing = false,
    bool clearChain = false,
  }) {
    return EditorState(
      plan: plan ?? this.plan,
      tool: tool ?? this.tool,
      selectedWallId: clearWall ? null : (selectedWallId ?? this.selectedWallId),
      selectedFurnitureId:
          clearFurniture ? null : (selectedFurnitureId ?? this.selectedFurnitureId),
      selectedOpeningId:
          clearOpening ? null : (selectedOpeningId ?? this.selectedOpeningId),
      placingCatalogId:
          clearPlacing ? null : (placingCatalogId ?? this.placingCatalogId),
      category: category ?? this.category,
      searchQuery: searchQuery ?? this.searchQuery,
      dirty: dirty ?? this.dirty,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      wallChainFrom: clearChain ? null : (wallChainFrom ?? this.wallChainFrom),
      detectedRooms: detectedRooms ?? this.detectedRooms,
    );
  }
}

class EditorNotifier extends StateNotifier<EditorState> {
  EditorNotifier(this._storage, FloorPlan plan)
      : super(
          EditorState(
            plan: plan,
            detectedRooms: detectRooms(plan.walls, names: plan.roomNames),
          ),
        );

  final PlanStorage _storage;
  final List<String> _undo = [];
  final List<String> _redo = [];
  static const _maxHistory = 60;
  bool _batching = false;

  void _pushHistory() {
    if (_batching) return;
    _undo.add(state.plan.encode());
    if (_undo.length > _maxHistory) _undo.removeAt(0);
    _redo.clear();
  }

  void _commit(
    FloorPlan plan, {
    EditorState Function(EditorState)? patch,
    bool redetectRooms = true,
  }) {
    final rooms = redetectRooms
        ? detectRooms(plan.walls, names: plan.roomNames)
        : state.detectedRooms;
    var next = state.copyWith(
      plan: plan,
      dirty: true,
      detectedRooms: rooms,
      canUndo: _undo.isNotEmpty,
      canRedo: _redo.isNotEmpty,
    );
    if (patch != null) next = patch(next);
    state = next.copyWith(
      canUndo: _undo.isNotEmpty,
      canRedo: _redo.isNotEmpty,
    );
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(state.plan.encode());
    final raw = _undo.removeLast();
    final plan = FloorPlan.decode(raw);
    state = state.copyWith(
      plan: plan,
      dirty: true,
      detectedRooms: detectRooms(plan.walls, names: plan.roomNames),
      canUndo: _undo.isNotEmpty,
      canRedo: _redo.isNotEmpty,
      clearWall: true,
      clearFurniture: true,
      clearOpening: true,
      clearChain: true,
    );
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(state.plan.encode());
    final raw = _redo.removeLast();
    final plan = FloorPlan.decode(raw);
    state = state.copyWith(
      plan: plan,
      dirty: true,
      detectedRooms: detectRooms(plan.walls, names: plan.roomNames),
      canUndo: _undo.isNotEmpty,
      canRedo: _redo.isNotEmpty,
      clearWall: true,
      clearFurniture: true,
      clearOpening: true,
      clearChain: true,
    );
  }

  void setTool(EditorTool tool) {
    state = state.copyWith(
      tool: tool,
      clearPlacing: tool != EditorTool.place,
      clearWall: true,
      clearFurniture: true,
      clearOpening: true,
      clearChain: tool != EditorTool.wall,
    );
  }

  void setCategory(CatalogCategory category) {
    state = state.copyWith(category: category);
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void beginPlacing(String catalogId) {
    state = state.copyWith(
      tool: EditorTool.place,
      placingCatalogId: catalogId,
      clearWall: true,
      clearFurniture: true,
      clearOpening: true,
      clearChain: true,
    );
  }

  void selectWall(String? id) {
    state = state.copyWith(
      selectedWallId: id,
      clearFurniture: true,
      clearOpening: true,
      tool: EditorTool.select,
    );
  }

  void selectFurniture(String? id) {
    state = state.copyWith(
      selectedFurnitureId: id,
      clearWall: true,
      clearOpening: true,
      tool: EditorTool.select,
    );
  }

  void selectOpening(String? id) {
    state = state.copyWith(
      selectedOpeningId: id,
      clearWall: true,
      clearFurniture: true,
      tool: EditorTool.select,
    );
  }

  void clearSelection() {
    state = state.copyWith(
      clearWall: true,
      clearFurniture: true,
      clearOpening: true,
    );
  }

  void addWall(Wall wall) {
    _pushHistory();
    final plan = state.plan.copy();
    plan.walls.add(wall);
    _commit(
      plan,
      patch: (s) => s.copyWith(
        selectedWallId: wall.id,
        wallChainFrom: wall.end,
        clearFurniture: true,
        clearOpening: true,
      ),
    );
  }

  void breakWallChain() {
    state = state.copyWith(clearChain: true);
  }

  void addOpening(WallOpening opening) {
    _pushHistory();
    final plan = state.plan.copy();
    plan.openings.add(opening);
    _commit(
      plan,
      patch: (s) => s.copyWith(
        selectedOpeningId: opening.id,
        clearWall: true,
        clearFurniture: true,
      ),
    );
  }

  void moveOpening(String id, double t) {
    final plan = state.plan.copy();
    final i = plan.openings.indexWhere((o) => o.id == id);
    if (i < 0) return;
    plan.openings[i].t = t.clamp(0.05, 0.95);
    _commit(plan, redetectRooms: false);
  }

  void beginGestureEdit() {
    if (_batching) return;
    _pushHistory();
    _batching = true;
  }

  void endGestureEdit() {
    _batching = false;
    state = state.copyWith(
      canUndo: _undo.isNotEmpty,
      canRedo: _redo.isNotEmpty,
    );
  }

  void moveFurniture(String id, double xCm, double yCm) {
    final plan = state.plan.copy();
    final i = plan.furniture.indexWhere((f) => f.id == id);
    if (i < 0) return;
    plan.furniture[i].xCm = xCm;
    plan.furniture[i].yCm = yCm;
    _commit(plan, redetectRooms: false);
  }

  void setFurnitureRotation(String id, double deg) {
    final plan = state.plan.copy();
    final i = plan.furniture.indexWhere((f) => f.id == id);
    if (i < 0) return;
    plan.furniture[i].rotationDeg = deg % 360;
    if (plan.furniture[i].rotationDeg < 0) {
      plan.furniture[i].rotationDeg += 360;
    }
    _commit(plan, redetectRooms: false);
  }

  void placeFurniture(PlacedFurniture item) {
    _pushHistory();
    final plan = state.plan.copy();
    plan.furniture.add(item);
    _commit(
      plan,
      patch: (s) => s.copyWith(
        selectedFurnitureId: item.id,
        tool: EditorTool.place,
        placingCatalogId: item.catalogId,
      ),
    );
  }

  void rotateSelected([double deltaDeg = 15]) {
    final id = state.selectedFurnitureId;
    if (id == null) return;
    _pushHistory();
    final plan = state.plan.copy();
    final i = plan.furniture.indexWhere((f) => f.id == id);
    if (i < 0) return;
    plan.furniture[i].rotationDeg =
        (plan.furniture[i].rotationDeg + deltaDeg) % 360;
    _commit(plan);
  }

  void setSelectedElevation(double elevationCm) {
    final id = state.selectedFurnitureId;
    if (id == null) return;
    _pushHistory();
    final plan = state.plan.copy();
    final i = plan.furniture.indexWhere((f) => f.id == id);
    if (i < 0) return;
    plan.furniture[i].elevationCm = elevationCm.clamp(0, 300);
    _commit(plan, redetectRooms: false);
  }

  void nudgeSelectedElevation(double deltaCm) {
    final id = state.selectedFurnitureId;
    if (id == null) return;
    final i = state.plan.furniture.indexWhere((f) => f.id == id);
    if (i < 0) return;
    setSelectedElevation(state.plan.furniture[i].elevationCm + deltaCm);
  }

  void placeStair(StairFlight stair) {
    _pushHistory();
    final plan = state.plan.copy();
    // Ensure destination level exists
    while (plan.levels.length <= stair.toLevelIndex) {
      final n = plan.levels.length + 1;
      plan.levels.add(
        PlanLevel(
          id: _uuid.v4(),
          name: n == 2 ? 'Upper floor' : 'Level $n',
          elevationCm: (n - 1) * 280.0,
        ),
      );
    }
    plan.stairs.add(stair);
    _commit(
      plan,
      patch: (s) => s.copyWith(
        tool: EditorTool.select,
        clearFurniture: true,
        clearOpening: true,
      ),
    );
  }

  void removeSelected() {
    _pushHistory();
    final plan = state.plan.copy();
    if (state.selectedFurnitureId != null) {
      // Stairs reuse furniture selection id space via selectedFurnitureId prefix? 
      // Stairs deleted via selectedOpeningId path below if we select them as openings.
      final stairIdx =
          plan.stairs.indexWhere((s) => s.id == state.selectedFurnitureId);
      if (stairIdx >= 0) {
        plan.stairs.removeAt(stairIdx);
        _commit(plan, patch: (s) => s.copyWith(clearFurniture: true));
        return;
      }
      plan.furniture.removeWhere((f) => f.id == state.selectedFurnitureId);
      _commit(plan, patch: (s) => s.copyWith(clearFurniture: true));
      return;
    }
    if (state.selectedOpeningId != null) {
      plan.openings.removeWhere((o) => o.id == state.selectedOpeningId);
      _commit(plan, patch: (s) => s.copyWith(clearOpening: true));
      return;
    }
    if (state.selectedWallId != null) {
      final wid = state.selectedWallId!;
      plan.openings.removeWhere((o) => o.wallId == wid);
      plan.walls.removeWhere((w) => w.id == wid);
      _commit(
        plan,
        patch: (s) => s.copyWith(clearWall: true, clearChain: true),
      );
    }
  }

  void renameRoom(String roomId, String name) {
    _pushHistory();
    final plan = state.plan.copy();
    plan.roomNames[roomId] = name.trim().isEmpty ? 'Room' : name.trim();
    _commit(plan);
  }

  void setActiveLevel(int index) {
    if (index < 0 || index >= state.plan.levels.length) return;
    final plan = state.plan.copy();
    plan.activeLevelIndex = index;
    state = state.copyWith(
      plan: plan,
      detectedRooms: detectRooms(plan.walls, names: plan.roomNames),
      clearWall: true,
      clearFurniture: true,
      clearOpening: true,
      clearChain: true,
    );
  }

  void addLevel() {
    _pushHistory();
    final plan = state.plan.copy();
    final n = plan.levels.length + 1;
    plan.levels.add(
      PlanLevel(
        id: _uuid.v4(),
        name: n == 2 ? 'Upper floor' : 'Level $n',
        elevationCm: (n - 1) * 280.0,
      ),
    );
    plan.activeLevelIndex = plan.levels.length - 1;
    _commit(
      plan,
      patch: (s) => s.copyWith(
        clearWall: true,
        clearFurniture: true,
        clearOpening: true,
        clearChain: true,
      ),
    );
  }

  void rename(String name) {
    _pushHistory();
    final plan = state.plan.copy();
    plan.name = name.trim().isEmpty ? plan.name : name.trim();
    _commit(plan);
  }

  Future<void> save() async {
    await _storage.save(state.plan);
    state = state.copyWith(dirty: false);
  }
}

final editorProvider = StateNotifierProvider.autoDispose
    .family<EditorNotifier, EditorState, FloorPlan>((ref, plan) {
  final storage = ref.watch(planStorageProvider);
  return EditorNotifier(storage, plan.copy());
});
