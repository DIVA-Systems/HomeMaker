import 'dart:math' as math;
import 'dart:ui';

import '../models/catalog_item.dart';
import '../theme/hm_colors.dart';

/// Flat architectural top-down symbols (SH3D planIcon style) — not 3D renders.
class PlanSymbolPainter {
  const PlanSymbolPainter._();

  static void paint(
    Canvas canvas, {
    required CatalogItem? item,
    required double widthCm,
    required double depthCm,
    required bool selected,
    required bool isDark,
    Color? tint,
  }) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: widthCm,
      height: depthCm,
    );
    final baseFill = tint ??
        (isDark ? const Color(0xFF2C322C) : const Color(0xFFF2EDE4));
    final fill = Paint()
      ..color = selected
          ? Color.alphaBlend(HmColors.spruce.withValues(alpha: 0.28), baseFill)
          : baseFill;
    final stroke = Paint()
      ..color = selected ? HmColors.selection : const Color(0xFF2A2E2C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? math.max(2.5, widthCm * 0.02) : math.max(1.6, widthCm * 0.015)
      ..strokeJoin = StrokeJoin.round;

    final kind = _kind(item);
    switch (kind) {
      case _SymbolKind.sofa:
        _sofa(canvas, rect, fill, stroke);
      case _SymbolKind.bed:
        _bed(canvas, rect, fill, stroke);
      case _SymbolKind.table:
        _table(canvas, rect, fill, stroke);
      case _SymbolKind.chair:
        _chair(canvas, rect, fill, stroke);
      case _SymbolKind.cabinet:
        _cabinet(canvas, rect, fill, stroke);
      case _SymbolKind.appliance:
        _appliance(canvas, rect, fill, stroke);
      case _SymbolKind.bath:
        _bath(canvas, rect, fill, stroke);
      case _SymbolKind.toilet:
        _toilet(canvas, rect, fill, stroke);
      case _SymbolKind.sink:
        _sink(canvas, rect, fill, stroke);
      case _SymbolKind.generic:
        _generic(canvas, rect, fill, stroke);
    }

    // Subtle front tick (SH3D orientation) — thin, not a heavy bar
    final front = Paint()
      ..color = const Color(0xFF2A2E2C)
      ..strokeWidth = math.max(1.2, widthCm * 0.012)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-widthCm / 2 + widthCm * 0.2, depthCm / 2 - depthCm * 0.03),
      Offset(widthCm / 2 - widthCm * 0.2, depthCm / 2 - depthCm * 0.03),
      front,
    );
  }

  static _SymbolKind _kind(CatalogItem? item) {
    if (item == null) return _SymbolKind.generic;
    final n = '${item.name} ${item.category}'.toLowerCase();
    if (n.contains('sofa') || n.contains('couch') || n.contains('futon')) {
      return _SymbolKind.sofa;
    }
    if (n.contains('bed') && !n.contains('table')) return _SymbolKind.bed;
    if (n.contains('chair') || n.contains('armchair') || n.contains('stool')) {
      return _SymbolKind.chair;
    }
    if (n.contains('table') || n.contains('desk')) return _SymbolKind.table;
    if (n.contains('toilet') || n.contains('bidet')) return _SymbolKind.toilet;
    if (n.contains('bath') || n.contains('shower') || n.contains('tub')) {
      return _SymbolKind.bath;
    }
    if (n.contains('sink') || n.contains('basin') || n.contains('vanity')) {
      return _SymbolKind.sink;
    }
    if (n.contains('fridge') ||
        n.contains('oven') ||
        n.contains('stove') ||
        n.contains('washer') ||
        n.contains('dishwasher') ||
        n.contains('microwave')) {
      return _SymbolKind.appliance;
    }
    if (n.contains('cabinet') ||
        n.contains('wardrobe') ||
        n.contains('shelf') ||
        n.contains('bookcase') ||
        n.contains('drawer')) {
      return _SymbolKind.cabinet;
    }
    return _SymbolKind.generic;
  }

  static void _generic(Canvas c, Rect r, Paint fill, Paint stroke) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * 0.06));
    c.drawRRect(rr, fill);
    c.drawRRect(rr, stroke);
  }

  static void _sofa(Canvas c, Rect r, Paint fill, Paint stroke) {
    // U-shape from top: seat + back + arms
    final path = Path();
    final inset = r.width * 0.14;
    final back = r.height * 0.22;
    path.moveTo(r.left, r.top);
    path.lineTo(r.right, r.top);
    path.lineTo(r.right, r.bottom);
    path.lineTo(r.right - inset, r.bottom);
    path.lineTo(r.right - inset, r.top + back);
    path.lineTo(r.left + inset, r.top + back);
    path.lineTo(r.left + inset, r.bottom);
    path.lineTo(r.left, r.bottom);
    path.close();
    c.drawPath(path, fill);
    c.drawPath(path, stroke);
  }

  static void _bed(Canvas c, Rect r, Paint fill, Paint stroke) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * 0.04));
    c.drawRRect(rr, fill);
    c.drawRRect(rr, stroke);
    // Headboard
    c.drawLine(
      Offset(r.left, r.top + r.height * 0.12),
      Offset(r.right, r.top + r.height * 0.12),
      stroke,
    );
    // Pillows
    final pw = r.width * 0.28;
    final ph = r.height * 0.14;
    final pillow = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke.strokeWidth;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left + r.width * 0.1, r.top + r.height * 0.16, pw, ph),
        const Radius.circular(3),
      ),
      pillow,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.right - r.width * 0.1 - pw, r.top + r.height * 0.16, pw, ph),
        const Radius.circular(3),
      ),
      pillow,
    );
  }

  static void _table(Canvas c, Rect r, Paint fill, Paint stroke) {
    final oval = r.deflate(r.shortestSide * 0.05);
    c.drawOval(oval, fill);
    c.drawOval(oval, stroke);
    // Legs hint
    final leg = r.shortestSide * 0.06;
    for (final o in [
      Offset(r.left + r.width * 0.25, r.top + r.height * 0.25),
      Offset(r.right - r.width * 0.25, r.top + r.height * 0.25),
      Offset(r.left + r.width * 0.25, r.bottom - r.height * 0.25),
      Offset(r.right - r.width * 0.25, r.bottom - r.height * 0.25),
    ]) {
      c.drawCircle(o, leg, stroke);
    }
  }

  static void _chair(Canvas c, Rect r, Paint fill, Paint stroke) {
    final seat = r.deflate(r.shortestSide * 0.12);
    c.drawRRect(
      RRect.fromRectAndRadius(seat, Radius.circular(seat.shortestSide * 0.15)),
      fill,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(seat, Radius.circular(seat.shortestSide * 0.15)),
      stroke,
    );
    // Backrest strip at top
    c.drawRect(
      Rect.fromLTWH(r.left + r.width * 0.15, r.top, r.width * 0.7, r.height * 0.18),
      stroke,
    );
  }

  static void _cabinet(Canvas c, Rect r, Paint fill, Paint stroke) {
    c.drawRect(r, fill);
    c.drawRect(r, stroke);
    // Door split
    c.drawLine(Offset(r.center.dx, r.top), Offset(r.center.dx, r.bottom), stroke);
  }

  static void _appliance(Canvas c, Rect r, Paint fill, Paint stroke) {
    c.drawRect(r, fill);
    c.drawRect(r, stroke);
    c.drawCircle(r.center, r.shortestSide * 0.18, stroke);
  }

  static void _bath(Canvas c, Rect r, Paint fill, Paint stroke) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * 0.35));
    c.drawRRect(rr, fill);
    c.drawRRect(rr, stroke);
    c.drawOval(r.deflate(r.shortestSide * 0.18), stroke);
  }

  static void _toilet(Canvas c, Rect r, Paint fill, Paint stroke) {
    final tank = Rect.fromLTWH(r.left + r.width * 0.15, r.top, r.width * 0.7, r.height * 0.28);
    final bowl = Rect.fromLTWH(
      r.left + r.width * 0.18,
      r.top + r.height * 0.28,
      r.width * 0.64,
      r.height * 0.62,
    );
    c.drawRect(tank, fill);
    c.drawRect(tank, stroke);
    c.drawOval(bowl, fill);
    c.drawOval(bowl, stroke);
  }

  static void _sink(Canvas c, Rect r, Paint fill, Paint stroke) {
    c.drawRect(r, fill);
    c.drawRect(r, stroke);
    c.drawOval(r.deflate(r.shortestSide * 0.2), stroke);
  }
}

enum _SymbolKind {
  sofa,
  bed,
  table,
  chair,
  cabinet,
  appliance,
  bath,
  toilet,
  sink,
  generic,
}
