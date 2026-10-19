import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/app_settings.dart';
import '../../geometry/plan_icon_renderer.dart';
import '../../geometry/plan_symbol.dart';
import '../../models/catalog_item.dart';
import '../../models/floor_plan.dart';
import '../../state/providers.dart';
import '../../theme/hm_colors.dart';
import '../../units/length_units.dart';
import '../common/glass_surface.dart';

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

enum _GestureMode {
  none,
  pan,
  wall,
  dragFurniture,
  rotateFurniture,
  dragOpening,
  dragWallEndpoint,
}

class _PlanCanvasState extends ConsumerState<PlanCanvas> {
  final _transform = TransformationController();
  final _canvasKey = GlobalKey();
  Size _viewport = Size.zero;
  bool _didFit = false;
  int _lastFitNonce = -1;

  _GestureMode _mode = _GestureMode.none;
  Offset? _wallStart;
  Offset? _wallCurrent;
  String? _draggingFurnitureId;
  String? _rotatingFurnitureId;
  String? _draggingOpeningId;
  String? _draggingWallId;
  bool _draggingWallIsStart = true;
  Offset? _lastFocalScene;
  double _startScale = 1;
  Matrix4? _startMatrix;
  double _gestureTravel = 0;
  bool _suppressNextTap = false;

  final Map<String, ui.Image> _iconCache = {};
  ui.Image? _overlayImage;
  String? _overlayFileLoaded;
  Offset? _lastDoubleTap;

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
      final image = await PlanIconRenderer.forItem(item);
      _iconCache[item.id] = image;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _ensureOverlay(FloorPlan plan) async {
    final o = plan.overlay;
    if (o == null || !o.visible) {
      if (_overlayImage != null) {
        _overlayImage = null;
        _overlayFileLoaded = null;
      }
      return;
    }
    if (_overlayFileLoaded == o.imageFileName && _overlayImage != null) return;
    try {
      final root = await getApplicationDocumentsDirectory();
      final file = File(p.join(root.path, 'overlays', o.imageFileName));
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _overlayImage = frame.image;
      _overlayFileLoaded = o.imageFileName;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  static const _minZoom = 0.12;
  static const _maxZoom = 8.0;
  static const _zoomStep = 1.35;

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
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
    _didFit = true;
    _lastFitNonce = widget.fitNonce;
  }

  /// Zoom toward [focal] in view space (defaults to viewport center).
  void _zoomAt(double factor, {Offset? focal}) {
    if (_viewport == Size.zero) return;
    final m = Matrix4.copy(_transform.value);
    final current = m.getMaxScaleOnAxis().clamp(_minZoom, _maxZoom);
    final desired = (current * factor).clamp(_minZoom, _maxZoom);
    if ((desired - current).abs() < 1e-6) return;
    final f = desired / current;
    final pivot = focal ?? Offset(_viewport.width / 2, _viewport.height / 2);
    final planPivot =
        MatrixUtils.transformPoint(Matrix4.inverted(m), pivot);
    m
      ..translateByDouble(planPivot.dx, planPivot.dy, 0, 1)
      ..scaleByDouble(f, f, f, 1)
      ..translateByDouble(-planPivot.dx, -planPivot.dy, 0, 1);
    _transform.value = m;
  }

  void _zoomIn() => _zoomAt(_zoomStep);
  void _zoomOut() => _zoomAt(1 / _zoomStep);

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // Trackpad / mouse wheel — zoom toward cursor
    final factor = event.scrollDelta.dy > 0 ? (1 / 1.12) : 1.12;
    _zoomAt(factor, focal: event.localPosition);
  }

  Offset _sceneToPlan(Offset scene) {
    final inv = Matrix4.inverted(_transform.value);
    return MatrixUtils.transformPoint(inv, scene);
  }

  double _snap(double v) => (v / _snapCm).round() * _snapCm;
  Offset _snapPoint(Offset p) => Offset(_snap(p.dx), _snap(p.dy));

  Offset _resolveWallStart(Offset raw, EditorState state, bool magnetism) {
    var p = _snapPoint(raw);
    if (!magnetism) return p;
    for (final w in state.plan.walls) {
      for (final ep in [w.start, w.end]) {
        if ((ep - p).distance <= _chainTol) return ep;
      }
    }
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
    _ensureOverlay(state.plan);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? HmColors.canvasDark : HmColors.canvas;
    final settings = ref.watch(appSettingsProvider);

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

          return Listener(
            onPointerSignal: _onPointerSignal,
            child: DragTarget<String>(
              onWillAcceptWithDetails: (_) => true,
              onAcceptWithDetails: (details) {
                final box =
                    _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                if (box == null) return;
                // details.offset is top-left of drag feedback; use center-ish.
                final local = box.globalToLocal(
                  details.offset + const Offset(46, 40),
                );
                final planPt = _snapPoint(_sceneToPlan(local));
                CatalogItem? item;
                for (final c in catalog) {
                  if (c.id == details.data) item = c;
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
              },
              builder: (context, candidate, rejected) {
                return GestureDetector(
                  key: _canvasKey,
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (d) =>
                      _onScaleStart(d, state, catalog, settings.magnetism),
                  onScaleUpdate: (d) =>
                      _onScaleUpdate(d, state, catalog, settings.magnetism),
                  onScaleEnd: (_) => _onScaleEnd(state),
                  onDoubleTapDown: (d) => _lastDoubleTap = d.localPosition,
                  onDoubleTap: () {
                    final at = _lastDoubleTap ??
                        Offset(_viewport.width / 2, _viewport.height / 2);
                    _zoomAt(_zoomStep, focal: at);
                  },
                  onTapUp: (d) => _onTap(d.localPosition, state, catalog),
                  onLongPress: () {
                    if (state.tool == EditorTool.wall) {
                      _editor.breakWallChain();
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _transform,
                    builder: (context, _) {
                      final zoom = _transform.value.getMaxScaleOnAxis();
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
                                    overlayImage: _overlayImage,
                                    selectedWallId: state.selectedWallId,
                                    selectedFurnitureId:
                                        state.selectedFurnitureId,
                                    selectedOpeningId: state.selectedOpeningId,
                                    draftStart: _wallStart,
                                    draftEnd: _wallCurrent,
                                    chainFrom: state.wallChainFrom,
                                    isDark: isDark,
                                    unitSystem: settings.unitSystem,
                                    showDimensions: settings.showDimensions,
                                    dropHighlight: candidate.isNotEmpty,
                                    viewScale: zoom,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: _CompassScaleOverlay(
                              planScale: zoom,
                              unitSystem: settings.unitSystem,
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: _ZoomControls(
                              zoom: zoom,
                              minZoom: _minZoom,
                              maxZoom: _maxZoom,
                              onZoomIn: _zoomIn,
                              onZoomOut: _zoomOut,
                              onFit: () => _fitToPlan(force: true),
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
        },
      ),
    );
  }

  void _onScaleStart(
    ScaleStartDetails d,
    EditorState state,
    List<CatalogItem> catalog,
    bool magnetism,
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
        _wallStart = _resolveWallStart(planPt, state, magnetism);
        _wallCurrent = _wallStart;
        setState(() {});
        return;
      case EditorTool.door:
      case EditorTool.window:
      case EditorTool.erase:
      case EditorTool.place:
      case EditorTool.stair:
        _mode = _GestureMode.pan;
        return;
      case EditorTool.select:
        // Wall endpoint handles (resize) — screen-sized hit so zoom feels right
        final ep = _hitWallEndpoint(planPt, state);
        if (ep != null) {
          _mode = _GestureMode.dragWallEndpoint;
          _draggingWallId = ep.$1;
          _draggingWallIsStart = ep.$2;
          _editor.selectWall(ep.$1);
          _editor.beginGestureEdit();
          return;
        }
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
          // Prefer selecting a wall so handles appear
          final wallHit = _hitWall(planPt, state.plan);
          if (wallHit != null) {
            _editor.selectWall(wallHit);
            _mode = _GestureMode.pan;
          } else {
            _mode = _GestureMode.pan;
          }
        }
        return;
    }
  }

  void _onScaleUpdate(
    ScaleUpdateDetails d,
    EditorState state,
    List<CatalogItem> catalog,
    bool magnetism,
  ) {
    if (_mode == _GestureMode.wall && _wallStart != null) {
      var end = _snapPoint(_sceneToPlan(d.localFocalPoint));
      if (magnetism) {
        for (final w in state.plan.walls) {
          for (final ep in [w.start, w.end]) {
            if ((ep - end).distance <= _chainTol) {
              end = ep;
              break;
            }
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

    if (_mode == _GestureMode.dragWallEndpoint && _draggingWallId != null) {
      var p = _snapPoint(_sceneToPlan(d.localFocalPoint));
      if (magnetism) {
        for (final w in state.plan.walls) {
          if (w.id == _draggingWallId) continue;
          for (final ep in [w.start, w.end]) {
            if ((ep - p).distance <= _chainTol) {
              p = ep;
              break;
            }
          }
        }
        // Ortho assist vs the fixed end
        final wall = state.plan.walls
            .cast<Wall?>()
            .firstWhere((w) => w?.id == _draggingWallId, orElse: () => null);
        if (wall != null) {
          final fixed = _draggingWallIsStart ? wall.end : wall.start;
          final delta = p - fixed;
          if (delta.dx.abs() < 15) {
            p = Offset(fixed.dx, p.dy);
          } else if (delta.dy.abs() < 15) {
            p = Offset(p.dx, fixed.dy);
          }
        }
      }
      _editor.moveWallEndpoint(
        wallId: _draggingWallId!,
        isStart: _draggingWallIsStart,
        point: p,
      );
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
      final desired = (_startScale * d.scale).clamp(_minZoom, _maxZoom);
      final m = Matrix4.copy(_startMatrix!);
      final factor = desired / m.getMaxScaleOnAxis();
      final focal = d.localFocalPoint;
      final focalPlan =
          MatrixUtils.transformPoint(Matrix4.inverted(m), focal);
      m
        ..translateByDouble(focalPlan.dx, focalPlan.dy, 0, 1)
        ..scaleByDouble(factor, factor, factor, 1)
        ..translateByDouble(-focalPlan.dx, -focalPlan.dy, 0, 1);
      final moved = focal - (_lastFocalScene ?? focal);
      m.translateByDouble(moved.dx, moved.dy, 0, 1);
      _transform.value = m;
      return;
    }

    _gestureTravel += d.focalPointDelta.distance;
    final m = Matrix4.copy(_transform.value);
    m.translateByDouble(d.focalPointDelta.dx, d.focalPointDelta.dy, 0, 1);
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
        _mode == _GestureMode.dragOpening ||
        _mode == _GestureMode.dragWallEndpoint) {
      _editor.endGestureEdit();
    }

    if (_gestureTravel > 12 ||
        _mode == _GestureMode.dragFurniture ||
        _mode == _GestureMode.wall ||
        _mode == _GestureMode.rotateFurniture ||
        _mode == _GestureMode.dragWallEndpoint) {
      _suppressNextTap = true;
    }

    _mode = _GestureMode.none;
    _wallStart = null;
    _wallCurrent = null;
    _draggingFurnitureId = null;
    _rotatingFurnitureId = null;
    _draggingOpeningId = null;
    _draggingWallId = null;
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

    if (state.tool == EditorTool.stair) {
      final to = math.min(
        state.plan.activeLevelIndex + 1,
        math.max(1, state.plan.levels.length),
      );
      _editor.placeStair(
        StairFlight(
          id: _uuid.v4(),
          xCm: planPt.dx,
          yCm: planPt.dy,
          fromLevelIndex: state.plan.activeLevelIndex,
          toLevelIndex: to == state.plan.activeLevelIndex
              ? state.plan.activeLevelIndex + 1
              : to,
        ),
      );
      return;
    }

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
      final hitS = _hitStair(planPt, state.plan);
      if (hitS != null) {
        _editor.selectFurniture(hitS);
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
      // Double-purpose: tap selected wall's mid label → edit length
      if (state.selectedWallId != null &&
          _hitWallDimension(planPt, state) == state.selectedWallId) {
        _showWallLengthDialog(state.selectedWallId!);
        return;
      }
      final open = _hitOpening(planPt, state);
      if (open != null) {
        _editor.selectOpening(open);
        return;
      }
      final hitS = _hitStair(planPt, state.plan);
      if (hitS != null) {
        _editor.selectFurniture(hitS);
        return;
      }
      final hitF = _hitFurniture(planPt, state.plan, catalog);
      if (hitF != null) {
        _editor.selectFurniture(hitF);
        return;
      }
      final hitW = _hitWall(planPt, state.plan);
      if (hitW != null) {
        if (hitW == state.selectedWallId) {
          _showWallLengthDialog(hitW);
        } else {
          _editor.selectWall(hitW);
        }
        return;
      }
      _editor.clearSelection();
    }
  }

  /// Returns (wallId, isStart) when near an endpoint handle.
  (String, bool)? _hitWallEndpoint(Offset p, EditorState state) {
    final scale = _transform.value.getMaxScaleOnAxis();
    final slop = math.max(16.0, 22.0 / scale);
    // Prefer selected wall's handles
    final ordered = [
      ...state.plan.walls.where((w) => w.id == state.selectedWallId),
      ...state.plan.walls.where((w) => w.id != state.selectedWallId),
    ];
    for (final w in ordered) {
      if ((w.start - p).distance <= slop) return (w.id, true);
      if ((w.end - p).distance <= slop) return (w.id, false);
    }
    return null;
  }

  String? _hitWallDimension(Offset p, EditorState state) {
    final id = state.selectedWallId;
    if (id == null) return null;
    Wall? wall;
    for (final w in state.plan.walls) {
      if (w.id == id) wall = w;
    }
    if (wall == null) return null;
    final mid = Offset(
      (wall.start.dx + wall.end.dx) / 2,
      (wall.start.dy + wall.end.dy) / 2,
    );
    final n = _wallNormalLocal(wall);
    final labelAt = mid + n * 18;
    final scale = _transform.value.getMaxScaleOnAxis();
    final slop = math.max(28.0, 36.0 / scale);
    if ((labelAt - p).distance <= slop) return id;
    return null;
  }

  Offset _wallNormalLocal(Wall w) {
    final d = w.end - w.start;
    final len = d.distance;
    if (len < 1e-6) return const Offset(0, -1);
    return Offset(-d.dy / len, d.dx / len);
  }

  Future<void> _showWallLengthDialog(String wallId) async {
    final state = ref.read(editorProvider(widget.planSeed));
    final wall = state.plan.walls
        .cast<Wall?>()
        .firstWhere((w) => w?.id == wallId, orElse: () => null);
    if (wall == null || !mounted) return;
    final units = ref.read(appSettingsProvider).unitSystem;
    final controller = TextEditingController(
      text: Units.formatLength(wall.lengthCm, units),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wall length'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: units == LengthUnitSystem.imperial
                ? 'e.g. 12\' 6" or 12.5'
                : 'e.g. 3.5 or 350',
            helperText: units == LengthUnitSystem.imperial
                ? 'Feet / inches, or decimal feet'
                : 'Meters or centimeters',
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resize'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final cm = Units.parseLengthToCm(controller.text, units);
    if (cm == null) return;
    _editor.setWallLength(wallId, cm);
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

  String? _hitStair(Offset p, FloorPlan plan) {
    final scale = _transform.value.getMaxScaleOnAxis();
    final slop = math.max(12.0, 28.0 / scale);
    for (final s in plan.stairs.reversed) {
      final rect = Rect.fromCenter(
        center: Offset(s.xCm, s.yCm),
        width: s.widthCm,
        height: s.depthCm,
      );
      if (rect.inflate(slop).contains(p)) return s.id;
    }
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

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  final double zoom;
  final double minZoom;
  final double maxZoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final pct = (zoom * 100).round().clamp(1, 999);
    final canIn = zoom < maxZoom - 1e-3;
    final canOut = zoom > minZoom + 1e-3;

    return GlassSurface(
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomBtn(
            icon: CupertinoIcons.plus,
            tooltip: 'Zoom in',
            enabled: canIn,
            onTap: onZoomIn,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '$pct%',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: HmColors.inkSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
          _ZoomBtn(
            icon: CupertinoIcons.minus,
            tooltip: 'Zoom out',
            enabled: canOut,
            onTap: onZoomOut,
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            width: 28,
            height: 1,
            color: HmColors.hairline,
          ),
          _ZoomBtn(
            icon: Icons.fit_screen_outlined,
            tooltip: 'Fit plan',
            enabled: true,
            onTap: onFit,
          ),
        ],
      ),
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  const _ZoomBtn({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(40, 40),
        onPressed: enabled ? onTap : null,
        child: Icon(
          icon,
          size: 20,
          color: enabled ? HmColors.spruce : HmColors.inkTertiary,
        ),
      ),
    );
  }
}

class _CompassScaleOverlay extends StatelessWidget {
  const _CompassScaleOverlay({
    required this.planScale,
    required this.unitSystem,
  });
  final double planScale;
  final LengthUnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    // Prefer ~1 m (metric) or ~3 ft (imperial) on screen.
    final targetCm = unitSystem == LengthUnitSystem.metric ? 100.0 : 91.44;
    final targetPx = targetCm * planScale;
    final barWidth = targetPx.clamp(40.0, 120.0);
    final barCm = barWidth / planScale;

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
                  Units.formatScaleBar(barCm, unitSystem),
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
    required this.overlayImage,
    required this.selectedWallId,
    required this.selectedFurnitureId,
    required this.selectedOpeningId,
    required this.draftStart,
    required this.draftEnd,
    required this.chainFrom,
    required this.isDark,
    required this.unitSystem,
    required this.showDimensions,
    this.dropHighlight = false,
    this.viewScale = 1,
  });

  final FloorPlan plan;
  final List<PlanRoom> rooms;
  final Map<String, CatalogItem> catalog;
  final Map<String, ui.Image> icons;
  final bool dropHighlight;
  final double viewScale;
  final ui.Image? overlayImage;
  final String? selectedWallId;
  final String? selectedFurnitureId;
  final String? selectedOpeningId;
  final Offset? draftStart;
  final Offset? draftEnd;
  final Offset? chainFrom;
  final bool isDark;
  final LengthUnitSystem unitSystem;
  final bool showDimensions;

  @override
  void paint(Canvas canvas, Size size) {
    final gridColor = isDark ? HmColors.canvasGridDark : HmColors.canvasGrid;
    _drawGrid(canvas, size, gridColor);

    // SH3D BackgroundImage — under walls
    final ov = plan.overlay;
    if (ov != null && ov.visible && overlayImage != null) {
      final rect = ov.planRectCm;
      paintImage(
        canvas: canvas,
        rect: rect,
        image: overlayImage!,
        fit: BoxFit.fill,
        opacity: ov.opacity,
        filterQuality: FilterQuality.medium,
      );
    }

    // Rooms
    for (var i = 0; i < rooms.length; i++) {
      final room = rooms[i];
      if (room.polygon.length < 3) continue;
      final path = Path()..addPolygon(room.polygon, true);
      final fill = Paint()
        ..color = HmColors.roomFill.withValues(alpha: 0.22 + (i % 3) * 0.06);
      canvas.drawPath(path, fill);
      final label =
          '${room.name}\n${Units.formatAreaM2(room.areaM2, unitSystem)}';
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
      if (selected) {
        // Resize handles (drag endpoints to lengthen / shorten)
        final handleR = math.max(9.0, 11.0 / viewScale);
        for (final ep in [w.start, w.end]) {
          canvas.drawCircle(ep, handleR + 2, Paint()..color = Colors.white);
          canvas.drawCircle(
            ep,
            handleR + 2,
            Paint()
              ..color = HmColors.spruce
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4,
          );
          canvas.drawCircle(ep, handleR * 0.35, Paint()..color = HmColors.spruce);
        }
      } else {
        canvas.drawCircle(w.start, 4.5, Paint()..color = HmColors.wall);
        canvas.drawCircle(w.end, 4.5, Paint()..color = HmColors.wall);
      }

      if (showDimensions) {
        final mid =
            Offset((w.start.dx + w.end.dx) / 2, (w.start.dy + w.end.dy) / 2);
        final n = _normal(w);
        _drawLabel(
          canvas,
          mid + n * 18,
          Units.formatLength(w.lengthCm, unitSystem),
        );
      }
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
        Units.formatLength(len, unitSystem),
      );
    }

    for (final s in plan.stairs) {
      _drawStair(canvas, s, s.id == selectedFurnitureId);
    }

    for (final f in plan.furniture) {
      _drawFurniture(canvas, f, f.id == selectedFurnitureId);
    }

    if (dropHighlight) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = HmColors.spruce.withValues(alpha: 0.08),
      );
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

  void _drawStair(Canvas canvas, StairFlight s, bool selected) {
    canvas.save();
    canvas.translate(s.xCm, s.yCm);
    canvas.rotate(s.rotationDeg * math.pi / 180);
    final rect =
        Rect.fromCenter(center: Offset.zero, width: s.widthCm, height: s.depthCm);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..color = selected
            ? HmColors.spruce.withValues(alpha: 0.2)
            : const Color(0x33B9A88E),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..color = selected ? HmColors.spruce : const Color(0xFF8A7A62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.5 : 1.4,
    );
    const steps = 8;
    for (var i = 1; i < steps; i++) {
      final y = -s.depthCm / 2 + s.depthCm * i / steps;
      canvas.drawLine(
        Offset(-s.widthCm / 2 + 4, y),
        Offset(s.widthCm / 2 - 4, y),
        Paint()
          ..color = const Color(0xFF8A7A62)
          ..strokeWidth = 1.2,
      );
    }
    // Direction arrow toward "up"
    canvas.drawLine(
      Offset(0, s.depthCm / 2 - 8),
      Offset(0, -s.depthCm / 2 + 8),
      Paint()
        ..color = HmColors.spruce
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
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
    final icon = icons[f.catalogId];

    // SH3D paintPieceOfFurnitureTop: stretch top-view icon to width × depth.
    if (icon != null) {
      paintImage(
        canvas: canvas,
        rect: rect,
        image: icon,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
      );
      if (f.materialColor != null) {
        canvas.drawRect(
          rect,
          Paint()
            ..color = f.materialColor!.withValues(alpha: 0.28)
            ..blendMode = BlendMode.srcATop,
        );
      }
      if (selected) {
        canvas.drawRect(
          rect,
          Paint()
            ..color = HmColors.selection
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.0, 2.5 / viewScale),
        );
      }
    } else {
      PlanSymbolPainter.paint(
        canvas,
        item: item,
        widthCm: w,
        depthCm: d,
        selected: selected,
        isDark: isDark,
        tint: f.materialColor,
      );
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
