import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart';

class ObjMesh {
  ObjMesh({
    required this.positions,
    required this.triangles,
    required this.normals,
  });

  final List<Vector3> positions;
  final List<List<int>> triangles; // each = 3 indices
  final List<Vector3> normals; // per triangle

  static final Map<String, Future<ObjMesh?>> _cache = {};

  static Future<ObjMesh?> loadAsset(String assetPath) {
    return _cache.putIfAbsent(assetPath, () => _parseAsset(assetPath));
  }

  static Future<ObjMesh?> _parseAsset(String assetPath) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      return parse(raw);
    } catch (_) {
      return null;
    }
  }

  static ObjMesh? parse(String raw) {
    final verts = <Vector3>[];
    final tris = <List<int>>[];

    for (final line in raw.split('\n')) {
      final t = line.trim();
      if (t.startsWith('v ')) {
        final p = t.split(RegExp(r'\s+'));
        if (p.length >= 4) {
          verts.add(
            Vector3(
              double.tryParse(p[1]) ?? 0,
              double.tryParse(p[2]) ?? 0,
              double.tryParse(p[3]) ?? 0,
            ),
          );
        }
      } else if (t.startsWith('f ')) {
        final p = t.split(RegExp(r'\s+')).skip(1).toList();
        final idx = <int>[];
        for (final part in p) {
          final i = int.tryParse(part.split('/')[0]);
          if (i != null) idx.add(i > 0 ? i - 1 : verts.length + i);
        }
        // Fan triangulation
        for (var i = 1; i + 1 < idx.length; i++) {
          tris.add([idx[0], idx[i], idx[i + 1]]);
        }
      }
    }

    if (verts.isEmpty || tris.isEmpty) return null;

    // Normalize to unit box centered on XZ, Y up from 0
    var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;
    for (final v in verts) {
      minX = math.min(minX, v.x);
      minY = math.min(minY, v.y);
      minZ = math.min(minZ, v.z);
      maxX = math.max(maxX, v.x);
      maxY = math.max(maxY, v.y);
      maxZ = math.max(maxZ, v.z);
    }
    final size = Vector3(maxX - minX, maxY - minY, maxZ - minZ);
    final scale = 1.0 / math.max(size.x, math.max(size.y, size.z)).clamp(1e-6, 1e9);
    final centered = verts
        .map(
          (v) => Vector3(
            (v.x - (minX + maxX) / 2) * scale,
            (v.y - minY) * scale,
            (v.z - (minZ + maxZ) / 2) * scale,
          ),
        )
        .toList();

    final normals = <Vector3>[];
    for (final t in tris) {
      final a = centered[t[0]];
      final b = centered[t[1]];
      final c = centered[t[2]];
      final n = (b - a).cross(c - a);
      if (n.length2 > 1e-12) {
        n.normalize();
      } else {
        n.setValues(0, 1, 0);
      }
      normals.add(n);
    }

    return ObjMesh(positions: centered, triangles: tris, normals: normals);
  }

  /// Axis-aligned footprint box used when OBJ missing.
  static ObjMesh box() {
    final v = [
      Vector3(-0.5, 0, -0.5),
      Vector3(0.5, 0, -0.5),
      Vector3(0.5, 0, 0.5),
      Vector3(-0.5, 0, 0.5),
      Vector3(-0.5, 1, -0.5),
      Vector3(0.5, 1, -0.5),
      Vector3(0.5, 1, 0.5),
      Vector3(-0.5, 1, 0.5),
    ];
    final tris = [
      [0, 1, 2],
      [0, 2, 3],
      [4, 6, 5],
      [4, 7, 6],
      [0, 4, 5],
      [0, 5, 1],
      [1, 5, 6],
      [1, 6, 2],
      [2, 6, 7],
      [2, 7, 3],
      [3, 7, 4],
      [3, 4, 0],
    ];
    final normals = <Vector3>[];
    for (final t in tris) {
      final n = (v[t[1]] - v[t[0]]).cross(v[t[2]] - v[t[0]])..normalize();
      normals.add(n);
    }
    return ObjMesh(positions: v, triangles: tris, normals: normals);
  }
}

class MeshDrawTri {
  MeshDrawTri(this.a, this.b, this.c, this.depth, this.color);
  final Offset a, b, c;
  final double depth;
  final Color color;
}
