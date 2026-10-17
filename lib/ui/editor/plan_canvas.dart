import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/catalog_item.dart';
import '../../models/floor_plan.dart';
import '../../state/providers.dart';
import '../../theme/hm_colors.dart';

const _uuid = Uuid();
const _canvasSize = Size(3200, 2400);
const _snapCm = 10.0;
const _chainTol = 25.0;

class PlanCanvas extends ConsumerStatefulWidget {
  const PlanCanvas({
    super.key,
    required this.planSeed,
    this.fitNonce = 0,
  });

  final FloorPlan planSeed;
  final int fitNonce;

  @override
  ConsumerState<PlanCanvas> createState() => _PlanCanvasState();
}

enum _GestureMode { none, pan, wall, dragFurniture, rotateFurniture, dragOpening }

class _PlanCanvasState extends ConsumerState<PlanCanvas> {
  final _transform = TransformationController();
  Size _viewport = Size.zero;
  bool _didFit = false;
  int _lastFitNonce = -1;

  _GestureMode _mode = _GestureMode.none;
  Offset? _wallStart;
  Offset? _wallCurrent;
  String? _draggingFurnitureId;
  String? _rotatingFurnitureId;
  String? _draggingOpeningId;
  Offset? _lastFocalScene;
  double _startScale = 1;
  Matrix4? _startMatrix;
  double _gestureTravel = 0;
  bool _suppressNextTap = false;

  final Map<String, ui.Image> _iconCache = {};

  EditorNotifier get _editor =>
      ref.read(editorProvider(widget.planSeed).notifier);

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlanCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fitNonce != widget.fitNonce) {
      _didFit = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitToPlan(force: true);
      });
    }
  }

  Future<void> _ensureIcon(CatalogItem item) async {
    if (_iconCache.containsKey(item.id)) return;
    try {
      final data = await DefaultAssetBundle.of(context).load(item.iconPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _iconCache[item.id] = frame.image;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _fitToPlan({bool force = false}) {
    if (_viewport == Size.zero) return;
    if (_didFit && !force && widget.fitNonce == _lastFitNonce) return;

    final state = ref.read(editorProvider(widget.planSeed));
    final bounds = state.plan.bounds.inflate(100);
    final vw = math.max(_viewport.width, 1.0);
    final vh = math.max(_viewport.height, 1.0);
    final scale =
        math.min(vw / bounds.width, vh / bounds.height).clamp(0.2, 2.5);

    final cx = bounds.center.dx;
    final cy = bounds.center.dy;
    final dx = vw / 2 - cx * scale;
    final dy = vh / 2 - cy * scale;

    _transform.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
    _didFit = true;
    _lastFitNonce = widget.fitNonce;
  }

  Offset _sceneToPlan(Offset scene) {
    final inv = Matrix4.inverted(_transform.value);
    return MatrixUtils.transformPoint(inv, scene);
  }

  double _snap(double v) => (v / _snapCm).round() * _snapCm;
  Offset _snapPoint(Offset p) => Offset(_snap(p.dx), _snap(p.dy));

  Offset _resolveWallStart(Offset raw, EditorState state) {
    var p = _snapPoint(raw);
    // Magnetism to existing endpoints
    for (final w in state.plan.walls) {
      for (final ep in [w.start, w.end]) {
        if ((ep - p).distance <= _chainTol) return ep;
      }
    }
    // Continue chain from last wall end
    final chain = state.wallChainFrom;
    if (chain != null && (chain - p).distance <= _chainTol * 2) {
      return chain;
    }
    return p;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorProvider(widget.planSeed));
    final catalogAsync = ref.watch(catalogProvider);
    final catalog = catalogAsync.valueOrNull ?? const <CatalogItem>[];
    final byId = {for (final c in catalog) c.id: c};
    for (final f in state.plan.furniture) {
      final item = byId[f.catalogId];
      if (item != null) _ensureIcon(item);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? HmColors.canvasDark : HmColors.canvas;

    return ColoredBox(
      color: bg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (size != _viewport) {
            _viewport = size;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fitToPlan();
            });
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (d) => _onScaleStart(d, state, catalog),
            onScaleUpdate: (d) => _onScaleUpdate(d, state, catalog),
            onScaleEnd: (_) => _onScaleEnd(state),
            onTapUp: (d) => _onTap(d.localPosition, state, catalog),
            onLongPress: () {
              if (state.tool == EditorTool.wall) {
                _editor.breakWallChain();
              }
            },
            child: AnimatedBuilder(
              animation: _transform,
              builder: (context, _) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRect(
                        child: Transform(
                          transform: _transform.value,
                          alignment: Alignment.topLeft,
                          filterQuality: FilterQuality.low,
                          child: CustomPaint(
                            size: _canvasSize,
                            isComplex: true,
                            willChange: _mode != _GestureMode.none,
                            painter: _PlanPainter(
                              plan: state.plan,
                              rooms: state.detectedRooms,
                              catalog: byId,
                              icons: _iconCache,
                              selectedWallId: state.selectedWallId,
                              selectedFurnitureId: state.selectedFurnitureId,
                              selectedOpeningId: state.selectedOpeningId,
                              draftStart: _wallStart,
                              draftEnd: _wallCurrent,
                              chainFrom: state.wallChainFrom,
                              isDark: isDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: _CompassScaleOverlay(
                        planScale: _transform.value.getMaxScaleOnAxis(),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _onScaleStart(
    ScaleStartDetails d,
    EditorState state,
    List<CatalogItem> catalog,
  ) {
    _startMatrix = Matrix4.copy(_transform.value);
    _startScale = _transform.value.getMaxScaleOnAxis();
    _lastFocalScene = d.localFocalPoint;
    _gestureTravel = 0;

    final planPt = _sceneToPlan(d.localFocalPoint);

    if (d.pointerCount >= 2) {
      _mode = _GestureMode.pan;
      return;
    }

    switch (state.tool) {
      case EditorTool.wall:
        _mode = _GestureMode.wall;
        _wallStart = _resolveWallStart(planPt, state);
        _wallCurrent = _wallStart;
        setState(() {});
        return;
      case EditorTool.door:
      case EditorTool.window:
      case EditorTool.erase:
      case EditorTool.place:
        _mode = _GestureMode.pan;
        return;
      case EditorTool.select:
        // Rotate handle takes priority
        final rot = _hitRotateHandle(planPt, state, catalog);
        if (rot != null) {
          _mode = _GestureMode.rotateFurniture;
          _rotatingFurnitureId = rot;
          _editor.selectFurniture(rot);
          _editor.beginGestureEdit();
          return;
        }
        final open = _hitOpening(planPt, state);
        if (open != null) {
          _mode = _GestureMode.dragOpening;
          _draggingOpeningId = open;
          _editor.selectOpening(open);
          _editor.beginGestureEdit();
          return;
        }
        final hit = _hitFurniture(planPt, state.plan, catalog);
        if (hit != null) {
          _mode = _GestureMode.dragFurniture;
          _draggingFurnitureId = hit;
          _editor.selectFurniture(hit);
          _editor.beginGestureEdit();
        } else {
          _mode = _GestureMode.pan;
        }
        return;
    }
  }

  void _onScaleUpdate(
    ScaleUpdateDetails d,
    EditorState state,
    List<CatalogItem> catalog,
  ) {
    if (_mode == _GestureMode.wall && _wallStart != null) {
      var end = _snapPoint(_sceneToPlan(d.localFocalPoint));
      // Snap end to nearby endpoints
      for (final w in state.plan.walls) {
        for (final ep in [w.start, w.end]) {
          if ((ep - end).distance <= _chainTol) {
            end = ep;
            break;
          }
        }
      }
      // Ortho assist when nearly horizontal/vertical
      final delta = end - _wallStart!;
      if (delta.dx.abs() < 15) {
        end = Offset(_wallStart!.dx, end.dy);
      } else if (delta.dy.abs() < 15) {
        end = Offset(end.dx, _wallStart!.dy);
      }
      _wallCurrent = end;
      setState(() {});
      return;
    }

    if (_mode == _GestureMode.dragFurniture && _draggingFurnitureId != null) {
      final p = _snapPoint(_sceneToPlan(d.localFocalPoint));
      _editor.moveFurniture(_draggingFurnitureId!, p.dx, p.dy);
      return;
    }

    if (_mode == _GestureMode.rotateFurniture && _rotatingFurnitureId != null) {
      final f = state.plan.furniture
          .cast<PlacedFurniture?>()
          .firstWhere((x) => x?.id == _rotatingFurnitureId, orElse: () => null);
      if (f != null) {
        final p = _sceneToPlan(d.localFocalPoint);
        final ang = math.atan2(p.dy - f.yCm, p.dx - f.xCm) * 180 / math.pi;
        // Snap to 15°
        final snapped = (ang / 15).round() * 15.0;
        _editor.setFurnitureRotation(f.id, snapped);
      }
      return;
    }

    if (_mode == _GestureMode.dragOpening && _draggingOpeningId != null) {
      final o = state.plan.openings
          .cast<WallOpening?>()
          .firstWhere((x) => x?.id == _draggingOpeningId, orElse: () => null);
      if (o != null) {
        final wall = state.plan.walls
            .cast<Wall?>()
            .firstWhere((w) => w?.id == o.wallId, orElse: () => null);
        if (wall != null) {
          final (t, _) = wall.project(_sceneToPlan(d.localFocalPoint));
          _editor.moveOpening(o.id, t);
        }
      }
      return;
    }

    if (_startMatrix == null) return;

    if (d.pointerCount >= 2 || (d.scale - 1.0).abs() > 0.008) {
      final desired = (_startScale * d.scale).clamp(0.15, 6.0);
      final m = Matrix4.copy(_startMatrix!);
      final factor = desired / m.getMaxScaleOnAxis();
      final focal = d.localFocalPoint;
      final focalPlan =
          MatrixUtils.transformPoint(Matrix4.inverted(m), focal);
      m
        ..translate(focalPlan.dx, focalPlan.dy)
        ..scale(factor)
        ..translate(-focalPlan.dx, -focalPlan.dy);
      final moved = focal - (_lastFocalScene ?? focal);
      m.translate(moved.dx, moved.dy);
      _transform.value = m;
      return;
    }

    _gestureTravel += d.focalPointDelta.distance;
    final m = Matrix4.copy(_transform.value);
    m.translate(d.focalPointDelta.dx, d.focalPointDelta.dy);
    _transform.value = m;
  }

  void _onScaleEnd(EditorState state) {
    if (_mode == _GestureMode.wall &&
        _wallStart != null &&
        _wallCurrent != null) {
      final dist = (_wallCurrent! - _wallStart!).distance;
      if (dist >= 20) {
        _editor.addWall(
          Wall(
            id: _uuid.v4(),
            start: _wallStart!,
            end: _wallCurrent!,
          ),
        );
      }
    }

    if (_mode == _GestureMode.dragFurniture ||
        _mode == _GestureMode.rotateFurniture ||
        _mode == _GestureMode.dragOpening) {
      _editor.endGestureEdit();
    }

    if (_gestureTravel > 12 ||
        _mode == _GestureMode.dragFurniture ||
        _mode == _GestureMode.wall ||
        _mode == _GestureMode.rotateFurniture) {
      _suppressNextTap = true;
    }

    _mode = _GestureMode.none;
    _wallStart = null;
    _wallCurrent = null;
    _draggingFurnitureId = null;
    _rotatingFurnitureId = null;
    _draggingOpeningId = null;
    _startMatrix = null;
    _lastFocalScene = null;
    _gestureTravel = 0;
    setState(() {});
  }

  void _onTap(Offset scene, EditorState state, List<CatalogItem> catalog) {
    if (_suppressNextTap) {
      _suppressNextTap = false;
      return;
    }
    final planPt = _snapPoint(_sceneToPlan(scene));

    if (state.tool == EditorTool.door || state.tool == EditorTool.window) {
      final hit = _nearestWall(planPt, state.plan);
      if (hit == null) return;
      final (wall, t) = hit;
      final kind =
          state.tool == EditorTool.door ? OpeningKind.door : OpeningKind.window;
      _editor.addOpening(
        WallOpening(
          id: _uuid.v4(),
          wallId: wall.id,
          kind: kind,
          t: t.clamp(0.08, 0.92),
          widthCm: kind == OpeningKind.door ? 90 : 120,
          heightCm: kind == OpeningKind.door ? 210 : 120,
          elevationCm: kind == OpeningKind.window ? 90 : 0,
        ),
      );
      return;
    }

    if (state.tool == EditorTool.place && state.placingCatalogId != null) {
      CatalogItem? item;
      for (final c in catalog) {
        if (c.id == state.placingCatalogId) item = c;
      }
      if (item == null) return;
      _editor.placeFurniture(
        PlacedFurniture(
          id: _uuid.v4(),
          catalogId: item.id,
          xCm: planPt.dx,
          yCm: planPt.dy,
          widthCm: item.widthCm,
          depthCm: item.depthCm,
        ),
      );
      return;
    }

    if (state.tool == EditorTool.erase) {
      final open = _hitOpening(planPt, state);
      if (open != null) {
        _editor.selectOpening(open);
        _editor.removeSelected();
        return;
      }
      final hitF = _hitFurniture(planPt, state.plan, catalog);
      if (hitF != null) {
        _editor.selectFurniture(hitF);
        _editor.removeSelected();
        return;
      }
      final hitW = _hitWall(planPt, state.plan);
      if (hitW != null) {
        _editor.selectWall(hitW);
        _editor.removeSelected();
      }
      return;
    }

    if (state.tool == EditorTool.select) {
      final open = _hitOpening(planPt, state);
      if (open != null) {
        _editor.selectOpening(open);
        return;
      }
      final hitF = _hitFurniture(planPt, state.plan, catalog);
      if (hitF != null) {
        _editor.selectFurniture(hitF);
        return;
      }
      final hitW = _hitWall(planPt, state.plan);
      if (hitW != null) {
        _editor.selectWall(hitW);
        return;
      }
      _editor.clearSelection();
    }
  }

  (Wall, double)? _nearestWall(Offset p, FloorPlan plan) {
    Wall? best;
    var bestDist = 40.0;
    var bestT = 0.5;
    for (final w in plan.walls) {
      final (t, dist) = w.project(p);
      if (dist < bestDist) {
        bestDist = dist;
        best = w;
        bestT = t;
      }
    }
    if (best == null) return null;
    return (best, bestT);
  }

  String? _hitOpening(Offset p, EditorState state) {
    final scale = _transform.value.getMaxScaleOnAxis();
    final slop = math.max(14.0, 28.0 / scale);
    for (final o in state.plan.openings.reversed) {
      final wall = state.plan.walls
          .cast<Wall?>()
          .firstWhere((w) => w?.id == o.wallId, orElse: () => null);
      if (wall == null) continue;
      final c = wall.pointAt(o.t);
      final half = o.widthCm / 2;
      if ((c - p).distance <= half + slop) return o.id;
    }
    return null;
  }

  String? _hitRotateHandle(
    Offset p,
    EditorState state,
    List<CatalogItem> catalog,
  ) {
    final id = state.selectedFurnitureId;
    if (id == null) return null;
    PlacedFurniture? f;
    for (final x in state.plan.furniture) {
      if (x.id == id) f = x;
    }
    if (f == null) return null;
    CatalogItem? item;
    for (final c in catalog) {
      if (c.id == f.catalogId) item = c;
    }
    final depth = f.depthCm ?? item?.depthCm ?? 60;
    final local = Offset(0, -depth / 2 - 36);
    final rad = f.rotationDeg * math.pi / 180;
    final handle = Offset(
      f.xCm + local.dx * math.cos(rad) - local.dy * math.sin(rad),
      f.yCm + local.dx * math.sin(rad) + local.dy * math.cos(rad),
    );
    final scale = _transform.value.getMaxScaleOnAxis();
    final slop = math.max(20.0, 36.0 / scale);
    if ((handle - p).distance <= slop) return f.id;
    return null;
  }

  String? _hitFurniture(
    Offset p,
    FloorPlan plan,
    List<CatalogItem> catalog,
  ) {
    final scale = _transform.value.getMaxScaleOnAxis();
    final slop = math.max(12.0, 28.0 / scale);
    for (final f in plan.furniture.reversed) {
      CatalogItem? item;
      for (final c in catalog) {
        if (c.id == f.catalogId) item = c;
      }
      final w = f.widthCm ?? item?.widthCm ?? 60;
      final d = f.depthCm ?? item?.depthCm ?? 60;
      final rect =
          Rect.fromCenter(center: Offset(f.xCm, f.yCm), width: w, height: d);
      if (rect.inflate(slop).contains(p)) return f.id;
    }
    return null;
  }

  String? _hitWall(Offset p, FloorPlan plan) {
    final scale = _transform.value.getMaxScaleOnAxis();
    final threshold = math.max(10.0, 22.0 / scale);
    for (final w in plan.walls) {
      final (_, dist) = w.project(p);
      if (dist <= threshold) return w.id;
    }
    return null;
  }
}

class _CompassScaleOverlay extends StatelessWidget {
  const _CompassScaleOverlay({required this.planScale});
  final double planScale;

  @override
  Widget build(BuildContext context) {
    // 1 m in plan cm = 100; screen pixels for 1 m = 100 * planScale
    final meterPx = 100 * planScale;
    final barWidth = meterPx.clamp(40.0, 120.0);
    final meters = barWidth / meterPx;

    return IgnorePointer(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HmColors.hairline),
            ),
            child: CustomPaint(painter: _CompassPainter()),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: HmColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: barWidth,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HmColors.spruce,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meters >= 0.95
                      ? '${meters.round()} m'
                      : '${(meters * 100).round()} cm',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: HmColors.inkSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 6;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = HmColors.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // North needle
    final path = Path()
      ..moveTo(c.dx, c.dy - r + 4)
      ..lineTo(c.dx + 5, c.dy + 2)
      ..lineTo(c.dx, c.dy - 2)
      ..lineTo(c.dx - 5, c.dy + 2)
      ..close();
    canvas.drawPath(path, Paint()..color = HmColors.clay);
    final tp = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: HmColors.spruce,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlanPainter extends CustomPainter {
  _PlanPainter({
    required this.plan,
    required this.rooms,
    required this.catalog,
    required this.icons,
    required this.selectedWallId,
    required this.selectedFurnitureId,
    required this.selectedOpeningId,
    required this.draftStart,
    required this.draftEnd,
    required this.chainFrom,
    required this.isDark,
  });

  final FloorPlan plan;
  final List<PlanRoom> rooms;
  final Map<String, CatalogItem> catalog;
  final Map<String, ui.Image> icons;
  final String? selectedWallId;
  final String? selectedFurnitureId;
  final String? selectedOpeningId;
  final Offset? draftStart;
  final Offset? draftEnd;
  final Offset? chainFrom;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final gridColor = isDark ? HmColors.canvasGridDark : HmColors.canvasGrid;
    _drawGrid(canvas, size, gridColor);

    // Rooms
    for (var i = 0; i < rooms.length; i++) {
      final room = rooms[i];
      if (room.polygon.length < 3) continue;
      final path = Path()..addPolygon(room.polygon, true);
      final fill = Paint()
        ..color = HmColors.roomFill.withValues(alpha: 0.22 + (i % 3) * 0.06);
      canvas.drawPath(path, fill);
      final label = '${room.name}\n${room.areaM2.toStringAsFixed(1)} m²';
      _drawLabel(canvas, room.centroid, label, multi: true);
    }

    // Walls with opening gaps
    for (final w in plan.walls) {
      final selected = w.id == selectedWallId;
      final segs = _wallSegments(w);
      for (final seg in segs) {
        canvas.drawLine(
          seg.$1,
          seg.$2,
          Paint()
            ..color = selected ? HmColors.wallSelected : HmColors.wall
            ..strokeWidth = selected ? 12 : 9
            ..strokeCap = StrokeCap.butt
            ..style = PaintingStyle.stroke,
        );
      }
      canvas.drawCircle(
        w.start,
        selected ? 6 : 4.5,
        Paint()..color = selected ? HmColors.spruceSoft : HmColors.wall,
      );
      canvas.drawCircle(
        w.end,
        selected ? 6 : 4.5,
        Paint()..color = selected ? HmColors.spruceSoft : HmColors.wall,
      );

      // Persistent dimension
      final mid = Offset((w.start.dx + w.end.dx) / 2, (w.start.dy + w.end.dy) / 2);
      final n = _normal(w);
      _drawLabel(
        canvas,
        mid + n * 18,
        '${(w.lengthCm / 100).toStringAsFixed(2)} m',
      );
    }

    // Openings
    for (final o in plan.openings) {
      final wall = plan.walls
          .cast<Wall?>()
          .firstWhere((w) => w?.id == o.wallId, orElse: () => null);
      if (wall == null) continue;
      _drawOpening(canvas, wall, o, o.id == selectedOpeningId);
    }

    if (chainFrom != null && draftStart == null) {
      canvas.drawCircle(
        chainFrom!,
        8,
        Paint()
          ..color = HmColors.spruceSoft.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        chainFrom!,
        8,
        Paint()
          ..color = HmColors.spruce
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    if (draftStart != null && draftEnd != null) {
      canvas.drawLine(
        draftStart!,
        draftEnd!,
        Paint()
          ..color = HmColors.spruceSoft.withValues(alpha: 0.9)
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      final len = (draftEnd! - draftStart!).distance;
      _drawLabel(
        canvas,
        Offset(
          (draftStart!.dx + draftEnd!.dx) / 2,
          (draftStart!.dy + draftEnd!.dy) / 2 - 20,
        ),
        '${(len / 100).toStringAsFixed(2)} m',
      );
    }

    for (final f in plan.furniture) {
      _drawFurniture(canvas, f, f.id == selectedFurnitureId);
    }
  }

  List<(Offset, Offset)> _wallSegments(Wall w) {
    final opens = plan.openings.where((o) => o.wallId == w.id).toList()
      ..sort((a, b) => a.t.compareTo(b.t));
    if (opens.isEmpty) return [(w.start, w.end)];

    final len = w.lengthCm;
    if (len < 1) return [(w.start, w.end)];
    final cuts = <(double, double)>[];
    for (final o in opens) {
      final half = (o.widthCm / len) / 2;
      cuts.add(((o.t - half).clamp(0.0, 1.0), (o.t + half).clamp(0.0, 1.0)));
    }
    // Merge
    cuts.sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(double, double)>[];
    for (final c in cuts) {
      if (merged.isEmpty || c.$1 > merged.last.$2) {
        merged.add(c);
      } else {
        merged[merged.length - 1] = (merged.last.$1, math.max(merged.last.$2, c.$2));
      }
    }

    final segs = <(Offset, Offset)>[];
    var cursor = 0.0;
    for (final m in merged) {
      if (m.$1 - cursor > 0.01) {
        segs.add((w.pointAt(cursor), w.pointAt(m.$1)));
      }
      cursor = m.$2;
    }
    if (1.0 - cursor > 0.01) {
      segs.add((w.pointAt(cursor), w.pointAt(1)));
    }
    return segs;
  }

  Offset _normal(Wall w) {
    final d = w.end - w.start;
    final len = d.distance;
    if (len < 1e-3) return const Offset(0, -1);
    return Offset(-d.dy / len, d.dx / len);
  }

  void _drawOpening(Canvas canvas, Wall wall, WallOpening o, bool selected) {
    final c = wall.pointAt(o.t);
    final d = wall.end - wall.start;
    final len = d.distance;
    if (len < 1) return;
    final dir = Offset(d.dx / len, d.dy / len);
    final n = Offset(-dir.dy, dir.dx);
    final half = o.widthCm / 2;
    final a = c - dir * half;
    final b = c + dir * half;

    // Clear gap already in wall segments; draw door/window glyph
    if (o.kind == OpeningKind.door) {
      final leafEnd = a + n * (half * 0.95);
      canvas.drawLine(
        a,
        leafEnd,
        Paint()
          ..color = selected ? HmColors.spruce : HmColors.inkSecondary
          ..strokeWidth = selected ? 3 : 2,
      );
      final startAng = math.atan2(n.dy, n.dx);
      canvas.drawArc(
        Rect.fromCircle(center: a, radius: half * 0.95),
        startAng,
        math.pi / 2,
        false,
        Paint()
          ..color = (selected ? HmColors.spruce : HmColors.inkSecondary)
              .withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = selected ? HmColors.spruce : const Color(0xFF5A6A5E)
          ..strokeWidth = 2,
      );
    } else {
      // Window: double line
      canvas.drawLine(
        a + n * 3,
        b + n * 3,
        Paint()
          ..color = selected ? HmColors.spruce : const Color(0xFF4A7A9A)
          ..strokeWidth = 2,
      );
      canvas.drawLine(
        a - n * 3,
        b - n * 3,
        Paint()
          ..color = selected ? HmColors.spruce : const Color(0xFF4A7A9A)
          ..strokeWidth = 2,
      );
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = selected ? HmColors.spruceSoft : const Color(0xFF6A9ABA)
          ..strokeWidth = 1.2,
      );
    }
  }

  void _drawFurniture(Canvas canvas, PlacedFurniture f, bool selected) {
    final item = catalog[f.catalogId];
    final w = f.widthCm ?? item?.widthCm ?? 60;
    final d = f.depthCm ?? item?.depthCm ?? 60;
    canvas.save();
    canvas.translate(f.xCm, f.yCm);
    canvas.rotate(f.rotationDeg * math.pi / 180);

    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: d);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..color = selected
            ? HmColors.spruce.withValues(alpha: 0.2)
            : (isDark ? const Color(0xFF2A2E2A) : Colors.white)
                .withValues(alpha: 0.95),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..color = selected ? HmColors.selection : HmColors.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3 : 1.4,
    );
    canvas.drawLine(
      Offset(-w / 2 + 4, d / 2 - 2),
      Offset(w / 2 - 4, d / 2 - 2),
      Paint()
        ..color = HmColors.spruce.withValues(alpha: 0.55)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    final icon = icons[f.catalogId];
    if (icon != null) {
      paintImage(
        canvas: canvas,
        rect: rect.deflate(5),
        image: icon,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    } else {
      final tp = TextPainter(
        text: TextSpan(
          text: item?.name ?? 'Item',
          style: TextStyle(
            color: isDark ? HmColors.inkDark : HmColors.ink,
            fontSize: math.min(14, w / 6),
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: w - 8);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    }

    if (selected) {
      // Rotate handle above piece (in local space: toward -depth)
      final handle = Offset(0, -d / 2 - 36);
      canvas.drawLine(
        Offset(0, -d / 2),
        handle,
        Paint()
          ..color = HmColors.spruceSoft
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(handle, 12, Paint()..color = Colors.white);
      canvas.drawCircle(
        handle,
        12,
        Paint()
          ..color = HmColors.spruce
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      // small rotate glyph
      canvas.drawArc(
        Rect.fromCircle(center: handle, radius: 6),
        -2.2,
        4.0,
        false,
        Paint()
          ..color = HmColors.spruce
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  void _drawGrid(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 50.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final major = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 1.5;
    for (double x = 0; x <= size.width; x += 100) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), major);
    }
    for (double y = 0; y <= size.height; y += 100) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), major);
    }
  }

  void _drawLabel(Canvas canvas, Offset at, String text, {bool multi = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: HmColors.spruce,
          fontSize: multi ? 12 : 12,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    final bg = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: at,
        width: tp.width + 12,
        height: tp.height + 8,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      bg,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PlanPainter old) => true;
}
