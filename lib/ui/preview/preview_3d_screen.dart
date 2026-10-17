import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/catalog_item.dart';
import '../../models/floor_plan.dart';
import '../../state/providers.dart';
import '../../theme/hm_colors.dart';

/// Lightweight isometric walkthrough of the current plan.
/// Full OBJ/Filament rendering comes later; this ships a readable 3D feel now.
class Preview3dScreen extends ConsumerStatefulWidget {
  const Preview3dScreen({super.key, required this.plan});

  final FloorPlan plan;

  @override
  ConsumerState<Preview3dScreen> createState() => _Preview3dScreenState();
}

class _Preview3dScreenState extends ConsumerState<Preview3dScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  double _yaw = 0.35;
  double _pitch = 0.55;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..addListener(() {
        setState(() => _yaw = 0.35 + _spin.value * math.pi * 2 * 0.08);
      });
    _spin.repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider).valueOrNull ?? const <CatalogItem>[];
    final map = {for (final c in catalog) c.id: c};

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.plan.name),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            if (_spin.isAnimating) {
              _spin.stop();
            } else {
              _spin.repeat();
            }
            setState(() {});
          },
          child: Icon(
            _spin.isAnimating ? CupertinoIcons.pause : CupertinoIcons.play_arrow,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                'Isometric preview · pinch drag to orbit',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: GestureDetector(
                onPanUpdate: (d) {
                  setState(() {
                    _yaw += d.delta.dx * 0.01;
                    _pitch = (_pitch + d.delta.dy * 0.008).clamp(0.25, 1.1);
                  });
                },
                child: CustomPaint(
                  painter: _IsoPainter(
                    plan: widget.plan,
                    catalog: map,
                    yaw: _yaw,
                    pitch: _pitch,
                    isDark: Theme.of(context).brightness == Brightness.dark,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${widget.plan.furniture.length} pieces · '
                '${widget.plan.walls.length} walls',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IsoPainter extends CustomPainter {
  _IsoPainter({
    required this.plan,
    required this.catalog,
    required this.yaw,
    required this.pitch,
    required this.isDark,
  });

  final FloorPlan plan;
  final Map<String, CatalogItem> catalog;
  final double yaw;
  final double pitch;
  final bool isDark;

  Offset _project(double x, double y, double z, Offset origin, double scale) {
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);
    final xr = x * cy - y * sy;
    final zr = x * sy + y * cy;
    final yr = z * cp - zr * sp;
    return Offset(origin.dx + xr * scale, origin.dy + yr * scale);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bg = isDark ? HmColors.canvasDark : const Color(0xFFE8E2D6);
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    final bounds = plan.bounds;
    final cx = bounds.center.dx;
    final cy = bounds.center.dy;
    final origin = Offset(size.width / 2, size.height * 0.62);
    final scale = math.min(size.width, size.height) / (bounds.longestSide + 200);

    // Floor plate
    final corners = [
      _project(bounds.left - cx, bounds.top - cy, 0, origin, scale),
      _project(bounds.right - cx, bounds.top - cy, 0, origin, scale),
      _project(bounds.right - cx, bounds.bottom - cy, 0, origin, scale),
      _project(bounds.left - cx, bounds.bottom - cy, 0, origin, scale),
    ];
    final floor = Path()..addPolygon(corners, true);
    canvas.drawPath(
      floor,
      Paint()..color = (isDark ? const Color(0xFF2A2E2A) : Colors.white).withValues(alpha: 0.9),
    );
    canvas.drawPath(
      floor,
      Paint()
        ..color = HmColors.spruce.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Walls as extruded quads
    for (final w in plan.walls) {
      const h = 250.0;
      final a0 = _project(w.start.dx - cx, w.start.dy - cy, 0, origin, scale);
      final a1 = _project(w.start.dx - cx, w.start.dy - cy, h, origin, scale);
      final b0 = _project(w.end.dx - cx, w.end.dy - cy, 0, origin, scale);
      final b1 = _project(w.end.dx - cx, w.end.dy - cy, h, origin, scale);
      final path = Path()
        ..moveTo(a0.dx, a0.dy)
        ..lineTo(b0.dx, b0.dy)
        ..lineTo(b1.dx, b1.dy)
        ..lineTo(a1.dx, a1.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = HmColors.wall.withValues(alpha: 0.55));
      canvas.drawPath(
        path,
        Paint()
          ..color = HmColors.wall
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Furniture as boxes
    for (final f in plan.furniture) {
      final item = catalog[f.catalogId];
      final w = f.widthCm ?? item?.widthCm ?? 60;
      final d = f.depthCm ?? item?.depthCm ?? 60;
      final h = item?.heightCm ?? 80;
      final rad = f.rotationDeg * math.pi / 180;
      final hx = w / 2;
      final hy = d / 2;
      final local = [
        Offset(-hx, -hy),
        Offset(hx, -hy),
        Offset(hx, hy),
        Offset(-hx, hy),
      ];
      Offset rot(Offset o) => Offset(
            o.dx * math.cos(rad) - o.dy * math.sin(rad),
            o.dx * math.sin(rad) + o.dy * math.cos(rad),
          );

      final bottom = <Offset>[];
      final top = <Offset>[];
      for (final o in local) {
        final r = rot(o);
        bottom.add(_project(f.xCm - cx + r.dx, f.yCm - cy + r.dy, 0, origin, scale));
        top.add(_project(f.xCm - cx + r.dx, f.yCm - cy + r.dy, h, origin, scale));
      }

      final body = Path()
        ..moveTo(top[0].dx, top[0].dy)
        ..lineTo(top[1].dx, top[1].dy)
        ..lineTo(top[2].dx, top[2].dy)
        ..lineTo(top[3].dx, top[3].dy)
        ..close();
      canvas.drawPath(body, Paint()..color = HmColors.spruceSoft.withValues(alpha: 0.75));

      for (var i = 0; i < 4; i++) {
        final j = (i + 1) % 4;
        final side = Path()
          ..moveTo(bottom[i].dx, bottom[i].dy)
          ..lineTo(bottom[j].dx, bottom[j].dy)
          ..lineTo(top[j].dx, top[j].dy)
          ..lineTo(top[i].dx, top[i].dy)
          ..close();
        canvas.drawPath(
          side,
          Paint()..color = HmColors.spruce.withValues(alpha: 0.35 + i * 0.05),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IsoPainter old) =>
      old.yaw != yaw || old.pitch != pitch || old.plan != plan;
}
