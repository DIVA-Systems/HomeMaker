import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import '../models/catalog_item.dart';
import 'obj_mesh.dart';

/// SH3D-style **top-view** furniture icons (orthographic XZ of the OBJ),
/// matching `PlanComponent.paintPieceOfFurnitureTop` / `PieceOfFurnitureModelIcon`.
class PlanIconRenderer {
  PlanIconRenderer._();

  static final Map<String, ui.Image> _cache = {};

  static ui.Image? cached(String catalogId) => _cache[catalogId];

  static Future<ui.Image> forItem(CatalogItem item) async {
    final hit = _cache[item.id];
    if (hit != null) return hit;

    ui.Image image;
    if (item.hasModel) {
      final mesh = await ObjMesh.loadAsset(item.modelPath);
      image = mesh != null
          ? await _fromMesh(mesh)
          : await _lineArtFallback(item);
    } else {
      image = await _lineArtFallback(item);
    }
    _cache[item.id] = image;
    return image;
  }

  /// True top-down: fill faces (painter's algorithm by Y), soft lighting from
  /// above, dark silhouette — not perspective catalog PNGs, not category blobs.
  static Future<ui.Image> _fromMesh(ObjMesh mesh) async {
    const size = 256.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    var minX = double.infinity, maxX = -double.infinity;
    var minZ = double.infinity, maxZ = -double.infinity;
    for (final p in mesh.positions) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minZ = math.min(minZ, p.z);
      maxZ = math.max(maxZ, p.z);
    }
    final bw = (maxX - minX).clamp(1e-6, 1e9);
    final bd = (maxZ - minZ).clamp(1e-6, 1e9);
    const pad = 10.0;
    final scale = math.min((size - pad * 2) / bw, (size - pad * 2) / bd);
    final midX = (minX + maxX) / 2;
    final midZ = (minZ + maxZ) / 2;
    final cx = size / 2;
    final cy = size / 2;

    Offset map(Vector3 p) => Offset(
          cx + (p.x - midX) * scale,
          cy + (p.z - midZ) * scale,
        );

    // Paint lower geometry first so tops read clearly.
    final order = List<int>.generate(mesh.triangles.length, (i) => i);
    order.sort((ia, ib) {
      double ay = 0, by = 0;
      for (final i in mesh.triangles[ia]) {
        ay += mesh.positions[i].y;
      }
      for (final i in mesh.triangles[ib]) {
        by += mesh.positions[i].y;
      }
      return ay.compareTo(by);
    });

    const base = Color(0xFFD9D0C3);
    for (final ti in order) {
      final t = mesh.triangles[ti];
      final a = mesh.positions[t[0]];
      final b = mesh.positions[t[1]];
      final c = mesh.positions[t[2]];
      final n = mesh.normals.length > ti
          ? mesh.normals[ti]
          : ((b - a).cross(c - a)..normalize());
      // Light from above (+Y) with a touch of +Z so fronts read slightly darker.
      final shade =
          (0.42 + 0.48 * n.y.abs() + 0.1 * math.max(0.0, -n.z)).clamp(0.35, 1.0);
      final fill = Paint()
        ..color = Color.fromARGB(
          255,
          ((base.r * 255.0) * shade).round().clamp(0, 255),
          ((base.g * 255.0) * shade).round().clamp(0, 255),
          ((base.b * 255.0) * shade).round().clamp(0, 255),
        )
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      final pa = map(a);
      final pb = map(b);
      final pc = map(c);
      canvas.drawPath(
        Path()
          ..moveTo(pa.dx, pa.dy)
          ..lineTo(pb.dx, pb.dy)
          ..lineTo(pc.dx, pc.dy)
          ..close(),
        fill,
      );
    }

    // Convex-hull silhouette (SH3D outline around the top view).
    final pts = mesh.positions.map(map).toList();
    final hull = _convexHull(pts);
    if (hull.length >= 3) {
      final path = Path()..moveTo(hull.first.dx, hull.first.dy);
      for (var i = 1; i < hull.length; i++) {
        path.lineTo(hull[i].dx, hull[i].dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF2C2F2C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final picture = recorder.endRecording();
    return picture.toImage(size.toInt(), size.toInt());
  }

  /// Architectural line-art when no mesh (import / missing model).
  static Future<ui.Image> _lineArtFallback(CatalogItem item) async {
    const size = 256.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final aspect = (item.widthCm / item.depthCm.clamp(1, 1e9)).clamp(0.35, 2.8);
    late Rect rect;
    if (aspect >= 1) {
      final h = 200 / aspect;
      rect = Rect.fromCenter(
        center: const Offset(size / 2, size / 2),
        width: 200,
        height: h,
      );
    } else {
      final w = 200 * aspect;
      rect = Rect.fromCenter(
        center: const Offset(size / 2, size / 2),
        width: w,
        height: 200,
      );
    }

    final fill = Paint()..color = const Color(0xFFF4EFE6);
    final ink = Paint()
      ..color = const Color(0xFF2A2E2C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round;

    final n = '${item.name} ${item.category}'.toLowerCase();
    if (n.contains('bed') && !n.contains('table')) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        ink,
      );
      canvas.drawLine(
        Offset(rect.left, rect.top + rect.height * 0.14),
        Offset(rect.right, rect.top + rect.height * 0.14),
        ink,
      );
      final pw = rect.width * 0.28;
      final ph = rect.height * 0.12;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + rect.width * 0.1, rect.top + rect.height * 0.18, pw, ph),
          const Radius.circular(2),
        ),
        ink,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.right - rect.width * 0.1 - pw, rect.top + rect.height * 0.18, pw, ph),
          const Radius.circular(2),
        ),
        ink,
      );
    } else if (n.contains('sofa') || n.contains('couch') || n.contains('futon')) {
      final path = Path();
      final inset = rect.width * 0.14;
      final back = rect.height * 0.22;
      path
        ..moveTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.right - inset, rect.bottom)
        ..lineTo(rect.right - inset, rect.top + back)
        ..lineTo(rect.left + inset, rect.top + back)
        ..lineTo(rect.left + inset, rect.bottom)
        ..lineTo(rect.left, rect.bottom)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, ink);
    } else if (n.contains('table') || n.contains('desk')) {
      canvas.drawOval(rect, fill);
      canvas.drawOval(rect, ink);
      final leg = rect.shortestSide * 0.05;
      for (final o in [
        Offset(rect.left + rect.width * 0.22, rect.top + rect.height * 0.22),
        Offset(rect.right - rect.width * 0.22, rect.top + rect.height * 0.22),
        Offset(rect.left + rect.width * 0.22, rect.bottom - rect.height * 0.22),
        Offset(rect.right - rect.width * 0.22, rect.bottom - rect.height * 0.22),
      ]) {
        canvas.drawCircle(o, leg, ink);
      }
    } else if (n.contains('chair') || n.contains('armchair')) {
      final seat = rect.deflate(rect.shortestSide * 0.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(seat, Radius.circular(seat.shortestSide * 0.12)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(seat, Radius.circular(seat.shortestSide * 0.12)),
        ink,
      );
      canvas.drawRect(
        Rect.fromLTWH(rect.left + rect.width * 0.18, rect.top, rect.width * 0.64, rect.height * 0.16),
        ink,
      );
    } else if (n.contains('toilet') || n.contains('bidet')) {
      canvas.drawRect(
        Rect.fromLTWH(rect.left + rect.width * 0.18, rect.top, rect.width * 0.64, rect.height * 0.28),
        fill,
      );
      canvas.drawRect(
        Rect.fromLTWH(rect.left + rect.width * 0.18, rect.top, rect.width * 0.64, rect.height * 0.28),
        ink,
      );
      canvas.drawOval(
        Rect.fromLTWH(rect.left + rect.width * 0.2, rect.top + rect.height * 0.3, rect.width * 0.6, rect.height * 0.58),
        fill,
      );
      canvas.drawOval(
        Rect.fromLTWH(rect.left + rect.width * 0.2, rect.top + rect.height * 0.3, rect.width * 0.6, rect.height * 0.58),
        ink,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide * 0.04)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide * 0.04)),
        ink,
      );
      if (n.contains('cabinet') || n.contains('fridge') || n.contains('wardrobe')) {
        canvas.drawLine(
          Offset(rect.center.dx, rect.top),
          Offset(rect.center.dx, rect.bottom),
          ink,
        );
      }
    }

    final picture = recorder.endRecording();
    return picture.toImage(size.toInt(), size.toInt());
  }

  static List<Offset> _convexHull(List<Offset> pts) {
    if (pts.length < 3) return List.of(pts);
    final sorted = List<Offset>.from(pts)
      ..sort((a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));
    final lower = <Offset>[];
    for (final p in sorted) {
      while (lower.length >= 2 &&
          _cross(lower[lower.length - 2], lower[lower.length - 1], p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }
    final upper = <Offset>[];
    for (final p in sorted.reversed) {
      while (upper.length >= 2 &&
          _cross(upper[upper.length - 2], upper[upper.length - 1], p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }
    lower.removeLast();
    upper.removeLast();
    return lower..addAll(upper);
  }

  static double _cross(Offset o, Offset a, Offset b) =>
      (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
}
