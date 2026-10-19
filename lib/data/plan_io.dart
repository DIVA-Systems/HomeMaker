import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../geometry/plan_symbol.dart';
import '../models/catalog_item.dart';
import '../models/floor_plan.dart';
import '../theme/hm_colors.dart';
import '../units/length_units.dart';

/// Export / import helpers (SH3D-style share of plans + images).
class PlanIo {
  /// Share plan as `.hmplan` JSON (portable HomeMaker project).
  static Future<void> exportHmplan(FloorPlan plan) async {
    final dir = await getTemporaryDirectory();
    final safe = plan.name.replaceAll(RegExp(r'[^\w\- ]'), '_').trim();
    final file = File(
      '${dir.path}/${safe.isEmpty ? 'plan' : safe}_${plan.id.substring(0, 8)}.hmplan',
    );
    await file.writeAsString(plan.encode());
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      text: '${plan.name} — HomeMaker plan',
    );
  }

  static FloorPlan? decodeHmplan(String raw) {
    try {
      return FloorPlan.decode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Rasterize 2D plan and share PNG.
  static Future<void> exportPlanPng({
    required FloorPlan plan,
    required Map<String, CatalogItem> catalog,
    required LengthUnitSystem unitSystem,
    bool isDark = false,
  }) async {
    final bounds = plan.bounds.inflate(80);
    const maxSide = 1600.0;
    final scale = maxSide / bounds.longestSide.clamp(1.0, 1e9);
    final w = (bounds.width * scale).ceil().clamp(200, 2400);
    final h = (bounds.height * scale).ceil().clamp(200, 2400);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = isDark ? HmColors.canvasDark : HmColors.canvas,
    );
    canvas.translate(-bounds.left * scale, -bounds.top * scale);
    canvas.scale(scale);

    for (final wall in plan.walls) {
      canvas.drawLine(
        wall.start,
        wall.end,
        Paint()
          ..color = HmColors.wall
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.butt,
      );
    }
    for (final f in plan.furniture) {
      final item = catalog[f.catalogId];
      final ww = f.widthCm ?? item?.widthCm ?? 60;
      final dd = f.depthCm ?? item?.depthCm ?? 60;
      canvas.save();
      canvas.translate(f.xCm, f.yCm);
      canvas.rotate(f.rotationDeg * 3.1415926535 / 180);
      PlanSymbolPainter.paint(
        canvas,
        item: item,
        widthCm: ww,
        depthCm: dd,
        selected: false,
        isDark: isDark,
        tint: f.materialColor,
      );
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/homemaker_plan_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes.buffer.asUint8List());
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: '${plan.name} — floor plan',
    );
  }

  /// Zip PNG frames into a turntable package (video substitute).
  static Future<void> shareTurntableZip(List<List<int>> pngFrames) async {
    if (pngFrames.isEmpty) return;
    final archive = Archive();
    for (var i = 0; i < pngFrames.length; i++) {
      final name = 'frame_${(i + 1).toString().padLeft(3, '0')}.png';
      archive.addFile(ArchiveFile(name, pngFrames[i].length, pngFrames[i]));
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) return;
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/homemaker_turntable_${DateTime.now().millisecondsSinceEpoch}.zip',
    );
    await file.writeAsBytes(encoded);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/zip')],
      text: 'HomeMaker 3D turntable frames',
    );
  }

  static Future<File?> pickHmplanFile() async {
    // Prefer share/open via temporary drop — callers use file_picker.
    return null;
  }

  static String suggestedImportName(String path) =>
      p.basenameWithoutExtension(path);
}
