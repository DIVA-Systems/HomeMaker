import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum OpeningKind { door, window }

class Wall {
  Wall({
    required this.id,
    required this.start,
    required this.end,
    this.thicknessCm = 12,
  });

  final String id;
  Offset start;
  Offset end;
  double thicknessCm;

  double get lengthCm => (end - start).distance;

  Offset pointAt(double t) => Offset.lerp(start, end, t.clamp(0.0, 1.0))!;

  /// Project point onto wall; returns (t, distance).
  (double t, double dist) project(Offset p) {
    final ab = end - start;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 < 1e-6) return (0.0, (p - start).distance);
    var t = ((p.dx - start.dx) * ab.dx + (p.dy - start.dy) * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    final proj = Offset(start.dx + ab.dx * t, start.dy + ab.dy * t);
    return (t, (p - proj).distance);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sx': start.dx,
        'sy': start.dy,
        'ex': end.dx,
        'ey': end.dy,
        'thicknessCm': thicknessCm,
      };

  factory Wall.fromJson(Map<String, dynamic> json) => Wall(
        id: json['id'] as String,
        start: Offset(
          (json['sx'] as num).toDouble(),
          (json['sy'] as num).toDouble(),
        ),
        end: Offset(
          (json['ex'] as num).toDouble(),
          (json['ey'] as num).toDouble(),
        ),
        thicknessCm: (json['thicknessCm'] as num?)?.toDouble() ?? 12,
      );

  Wall copy() => Wall(
        id: id,
        start: start,
        end: end,
        thicknessCm: thicknessCm,
      );
}

class WallOpening {
  WallOpening({
    required this.id,
    required this.wallId,
    required this.kind,
    required this.t,
    this.widthCm = 90,
    this.heightCm = 210,
    this.elevationCm = 0,
  });

  final String id;
  final String wallId;
  OpeningKind kind;
  double t; // 0..1 along wall center
  double widthCm;
  double heightCm;
  double elevationCm;

  Map<String, dynamic> toJson() => {
        'id': id,
        'wallId': wallId,
        'kind': kind.name,
        't': t,
        'widthCm': widthCm,
        'heightCm': heightCm,
        'elevationCm': elevationCm,
      };

  factory WallOpening.fromJson(Map<String, dynamic> json) => WallOpening(
        id: json['id'] as String,
        wallId: json['wallId'] as String,
        kind: OpeningKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => OpeningKind.door,
        ),
        t: (json['t'] as num).toDouble(),
        widthCm: (json['widthCm'] as num?)?.toDouble() ?? 90,
        heightCm: (json['heightCm'] as num?)?.toDouble() ?? 210,
        elevationCm: (json['elevationCm'] as num?)?.toDouble() ?? 0,
      );

  WallOpening copy() => WallOpening(
        id: id,
        wallId: wallId,
        kind: kind,
        t: t,
        widthCm: widthCm,
        heightCm: heightCm,
        elevationCm: elevationCm,
      );
}

class PlacedFurniture {
  PlacedFurniture({
    required this.id,
    required this.catalogId,
    required this.xCm,
    required this.yCm,
    this.rotationDeg = 0,
    this.widthCm,
    this.depthCm,
  });

  final String id;
  final String catalogId;
  double xCm;
  double yCm;
  double rotationDeg;
  double? widthCm;
  double? depthCm;

  Map<String, dynamic> toJson() => {
        'id': id,
        'catalogId': catalogId,
        'xCm': xCm,
        'yCm': yCm,
        'rotationDeg': rotationDeg,
        'widthCm': widthCm,
        'depthCm': depthCm,
      };

  factory PlacedFurniture.fromJson(Map<String, dynamic> json) =>
      PlacedFurniture(
        id: json['id'] as String,
        catalogId: json['catalogId'] as String,
        xCm: (json['xCm'] as num).toDouble(),
        yCm: (json['yCm'] as num).toDouble(),
        rotationDeg: (json['rotationDeg'] as num?)?.toDouble() ?? 0,
        widthCm: (json['widthCm'] as num?)?.toDouble(),
        depthCm: (json['depthCm'] as num?)?.toDouble(),
      );

  PlacedFurniture copy() => PlacedFurniture(
        id: id,
        catalogId: catalogId,
        xCm: xCm,
        yCm: yCm,
        rotationDeg: rotationDeg,
        widthCm: widthCm,
        depthCm: depthCm,
      );
}

class PlanRoom {
  PlanRoom({
    required this.id,
    required this.name,
    required this.polygon,
  });

  final String id;
  String name;
  final List<Offset> polygon;

  double get areaM2 {
    if (polygon.length < 3) return 0;
    var sum = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return (sum.abs() / 2) / 10000; // cm² → m²
  }

  Offset get centroid {
    if (polygon.isEmpty) return Offset.zero;
    var x = 0.0;
    var y = 0.0;
    for (final p in polygon) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / polygon.length, y / polygon.length);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'polygon': polygon.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      };

  factory PlanRoom.fromJson(Map<String, dynamic> json) => PlanRoom(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Room',
        polygon: (json['polygon'] as List<dynamic>? ?? [])
            .map(
              (e) => Offset(
                (e['x'] as num).toDouble(),
                (e['y'] as num).toDouble(),
              ),
            )
            .toList(),
      );

  PlanRoom copy() => PlanRoom(
        id: id,
        name: name,
        polygon: List<Offset>.from(polygon),
      );
}

class PlanLevel {
  PlanLevel({
    required this.id,
    required this.name,
    List<Wall>? walls,
    List<WallOpening>? openings,
    List<PlacedFurniture>? furniture,
    this.elevationCm = 0,
  })  : walls = walls ?? [],
        openings = openings ?? [],
        furniture = furniture ?? [];

  final String id;
  String name;
  double elevationCm;
  final List<Wall> walls;
  final List<WallOpening> openings;
  final List<PlacedFurniture> furniture;

  PlanLevel copy() => PlanLevel(
        id: id,
        name: name,
        elevationCm: elevationCm,
        walls: walls.map((w) => w.copy()).toList(),
        openings: openings.map((o) => o.copy()).toList(),
        furniture: furniture.map((f) => f.copy()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'elevationCm': elevationCm,
        'walls': walls.map((w) => w.toJson()).toList(),
        'openings': openings.map((o) => o.toJson()).toList(),
        'furniture': furniture.map((f) => f.toJson()).toList(),
      };

  factory PlanLevel.fromJson(Map<String, dynamic> json) => PlanLevel(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Level',
        elevationCm: (json['elevationCm'] as num?)?.toDouble() ?? 0,
        walls: (json['walls'] as List<dynamic>? ?? [])
            .map((e) => Wall.fromJson(e as Map<String, dynamic>))
            .toList(),
        openings: (json['openings'] as List<dynamic>? ?? [])
            .map((e) => WallOpening.fromJson(e as Map<String, dynamic>))
            .toList(),
        furniture: (json['furniture'] as List<dynamic>? ?? [])
            .map((e) => PlacedFurniture.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class FloorPlan {
  FloorPlan({
    required this.id,
    required this.name,
    List<PlanLevel>? levels,
    this.activeLevelIndex = 0,
    DateTime? updatedAt,
    this.unitsPerCm = 1,
    Map<String, String>? roomNames,
  })  : levels = levels ??
            [
              PlanLevel(id: _uuid.v4(), name: 'Ground floor'),
            ],
        updatedAt = updatedAt ?? DateTime.now(),
        roomNames = roomNames ?? {};

  final String id;
  String name;
  final List<PlanLevel> levels;
  int activeLevelIndex;
  DateTime updatedAt;
  double unitsPerCm;

  /// Stable id → display name for detected rooms.
  final Map<String, String> roomNames;

  PlanLevel get activeLevel {
    if (levels.isEmpty) {
      levels.add(PlanLevel(id: _uuid.v4(), name: 'Ground floor'));
    }
    activeLevelIndex = activeLevelIndex.clamp(0, levels.length - 1);
    return levels[activeLevelIndex];
  }

  List<Wall> get walls => activeLevel.walls;
  List<WallOpening> get openings => activeLevel.openings;
  List<PlacedFurniture> get furniture => activeLevel.furniture;

  factory FloorPlan.blank({String name = 'Untitled plan'}) => FloorPlan(
        id: _uuid.v4(),
        name: name,
      );

  factory FloorPlan.starter({String name = 'My first room'}) {
    const w = 500.0;
    const d = 400.0;
    const o = 80.0;
    final level = PlanLevel(
      id: _uuid.v4(),
      name: 'Ground floor',
      walls: [
        Wall(id: _uuid.v4(), start: const Offset(o, o), end: const Offset(o + w, o)),
        Wall(
          id: _uuid.v4(),
          start: const Offset(o + w, o),
          end: const Offset(o + w, o + d),
        ),
        Wall(
          id: _uuid.v4(),
          start: const Offset(o + w, o + d),
          end: const Offset(o, o + d),
        ),
        Wall(id: _uuid.v4(), start: const Offset(o, o + d), end: const Offset(o, o)),
      ],
    );
    return FloorPlan(
      id: _uuid.v4(),
      name: name,
      levels: [level],
    );
  }

  FloorPlan copy() => FloorPlan(
        id: id,
        name: name,
        levels: levels.map((l) => l.copy()).toList(),
        activeLevelIndex: activeLevelIndex,
        updatedAt: updatedAt,
        unitsPerCm: unitsPerCm,
        roomNames: Map<String, String>.from(roomNames),
      );

  Rect get bounds {
    final ws = walls;
    final fs = furniture;
    if (ws.isEmpty && fs.isEmpty) {
      return const Rect.fromLTWH(0, 0, 600, 500);
    }
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;
    for (final w in ws) {
      minX = math.min(minX, math.min(w.start.dx, w.end.dx));
      minY = math.min(minY, math.min(w.start.dy, w.end.dy));
      maxX = math.max(maxX, math.max(w.start.dx, w.end.dx));
      maxY = math.max(maxY, math.max(w.start.dy, w.end.dy));
    }
    for (final f in fs) {
      minX = math.min(minX, f.xCm - 50);
      minY = math.min(minY, f.yCm - 50);
      maxX = math.max(maxX, f.xCm + 50);
      maxY = math.max(maxY, f.yCm + 50);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'updatedAt': updatedAt.toIso8601String(),
        'unitsPerCm': unitsPerCm,
        'activeLevelIndex': activeLevelIndex,
        'levels': levels.map((l) => l.toJson()).toList(),
        'roomNames': roomNames,
        // legacy flat fields for older readers
        'walls': walls.map((w) => w.toJson()).toList(),
        'furniture': furniture.map((f) => f.toJson()).toList(),
        'openings': openings.map((o) => o.toJson()).toList(),
      };

  factory FloorPlan.fromJson(Map<String, dynamic> json) {
    final levelsJson = json['levels'] as List<dynamic>?;
    List<PlanLevel> levels;
    if (levelsJson != null && levelsJson.isNotEmpty) {
      levels = levelsJson
          .map((e) => PlanLevel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      // Migrate legacy flat plans
      levels = [
        PlanLevel(
          id: _uuid.v4(),
          name: 'Ground floor',
          walls: (json['walls'] as List<dynamic>? ?? [])
              .map((e) => Wall.fromJson(e as Map<String, dynamic>))
              .toList(),
          furniture: (json['furniture'] as List<dynamic>? ?? [])
              .map((e) => PlacedFurniture.fromJson(e as Map<String, dynamic>))
              .toList(),
          openings: (json['openings'] as List<dynamic>? ?? [])
              .map((e) => WallOpening.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      ];
    }

    final namesRaw = json['roomNames'] as Map<String, dynamic>? ?? {};
    return FloorPlan(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      unitsPerCm: (json['unitsPerCm'] as num?)?.toDouble() ?? 1,
      activeLevelIndex: (json['activeLevelIndex'] as num?)?.toInt() ?? 0,
      levels: levels,
      roomNames: namesRaw.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  String encode() => jsonEncode(toJson());

  static FloorPlan decode(String raw) =>
      FloorPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
