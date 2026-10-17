import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import '../../data/app_settings.dart';
import '../../geometry/obj_mesh.dart';
import '../../models/catalog_item.dart';
import '../../models/floor_plan.dart';
import '../../state/providers.dart';
import '../../theme/hm_colors.dart';

enum _ViewMode { orbit, visit }

class Preview3dScreen extends ConsumerStatefulWidget {
  const Preview3dScreen({super.key, required this.plan});

  final FloorPlan plan;

  @override
  ConsumerState<Preview3dScreen> createState() => _Preview3dScreenState();
}

class _Preview3dScreenState extends ConsumerState<Preview3dScreen>
    with SingleTickerProviderStateMixin {
  final _shotKey = GlobalKey();
  _ViewMode _mode = _ViewMode.orbit;

  double _yaw = 0.6;
  double _pitch = 0.75;
  double _distance = 900;
  late Offset _target;

  late Vector3 _eye;
  double _lookYaw = 0;
  double _lookPitch = 0;
  Offset _stick = Offset.zero;

  late final AnimationController _ticker;
  final Map<String, ObjMesh?> _meshes = {};
  bool _loadingMeshes = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    final b = widget.plan.bounds;
    _target = Offset(b.center.dx, b.center.dy);
    _eye = Vector3(b.center.dx, 160, b.center.dy + 120);
    _distance = math.max(b.longestSide * 1.25, 520);
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..addListener(_onTick)
      ..repeat();
    _loadMeshes();
  }

  Future<void> _loadMeshes() async {
    final catalog = await ref.read(catalogProvider.future);
    final byId = {for (final c in catalog) c.id: c};
    for (final f in widget.plan.furniture) {
      final item = byId[f.catalogId];
      if (item == null) continue;
      if (_meshes.containsKey(item.id)) continue;
      _meshes[item.id] = await ObjMesh.loadAsset(item.modelPath);
    }
    if (mounted) setState(() => _loadingMeshes = false);
  }

  void _onTick() {
    if (_mode != _ViewMode.visit || _stick.distance < 0.06) return;
    const speed = 5.0;
    final forward = Vector3(math.sin(_lookYaw), 0, -math.cos(_lookYaw));
    final right = Vector3(math.cos(_lookYaw), 0, math.sin(_lookYaw));
    _eye += forward * (-_stick.dy * speed) + right * (_stick.dx * speed);
    final b = widget.plan.bounds.inflate(30);
    _eye.x = _eye.x.clamp(b.left, b.right);
    _eye.z = _eye.z.clamp(b.top, b.bottom);
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    try {
      setState(() => _status = 'Capturing…');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final boundary =
          _shotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/homemaker_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${widget.plan.name} — HomeMaker 3D',
      );
      if (mounted) setState(() => _status = 'Photo shared');
    } catch (_) {
      if (mounted) setState(() => _status = 'Capture failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog =
        ref.watch(catalogProvider).valueOrNull ?? const <CatalogItem>[];
    final map = {for (final c in catalog) c.id: c};
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan.name),
        actions: [
          IconButton(
            tooltip: 'Take photo',
            onPressed: _capturePhoto,
            icon: const Icon(Icons.camera_alt_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<_ViewMode>(
              segments: const [
                ButtonSegment(
                  value: _ViewMode.orbit,
                  label: Text('Orbit'),
                  icon: Icon(Icons.threed_rotation, size: 18),
                ),
                ButtonSegment(
                  value: _ViewMode.visit,
                  label: Text('Visit'),
                  icon: Icon(Icons.accessibility_new, size: 18),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() {
                _mode = s.first;
                _stick = Offset.zero;
              }),
            ),
          ),
          if (_loadingMeshes) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    key: _shotKey,
                    child: GestureDetector(
                      onScaleUpdate: (d) {
                        setState(() {
                          if (_mode == _ViewMode.orbit) {
                            _yaw -= d.focalPointDelta.dx * 0.01;
                            _pitch = (_pitch + d.focalPointDelta.dy * 0.008)
                                .clamp(0.2, 1.45);
                            if (d.pointerCount >= 2) {
                              _distance = (_distance / d.scale)
                                  .clamp(250.0, 3500.0);
                            }
                          } else {
                            _lookYaw -= d.focalPointDelta.dx * 0.01;
                            _lookPitch =
                                (_lookPitch + d.focalPointDelta.dy * 0.008)
                                    .clamp(-0.65, 0.65);
                          }
                        });
                      },
                      child: CustomPaint(
                        painter: _Home3dPainter(
                          plan: widget.plan,
                          catalog: map,
                          meshes: _meshes,
                          mode: _mode,
                          yaw: _yaw,
                          pitch: _pitch,
                          distance: _distance,
                          target: _target,
                          eye: _eye,
                          lookYaw: _lookYaw,
                          lookPitch: _lookPitch,
                          lightIntensity: settings.lightIntensity,
                          ambient: settings.ambientLight,
                          isDark:
                              Theme.of(context).brightness == Brightness.dark,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                if (_mode == _ViewMode.visit)
                  Positioned(
                    left: 24,
                    bottom: 24,
                    child: _VirtualStick(
                      onChanged: (v) => setState(() => _stick = v),
                    ),
                  ),
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: Text(
                    _status ??
                        (_mode == _ViewMode.orbit
                            ? 'Drag orbit · pinch zoom · camera for photo'
                            : 'Drag to look · stick to walk · camera for photo'),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          shadows: const [
                            Shadow(blurRadius: 8, color: Colors.black54),
                          ],
                        ),
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

class _VirtualStick extends StatefulWidget {
  const _VirtualStick({required this.onChanged});
  final ValueChanged<Offset> onChanged;

  @override
  State<_VirtualStick> createState() => _VirtualStickState();
}

class _VirtualStickState extends State<_VirtualStick> {
  Offset _delta = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) {
        final next = Offset(
          (_delta.dx + d.delta.dx / 48).clamp(-1.0, 1.0),
          (_delta.dy + d.delta.dy / 48).clamp(-1.0, 1.0),
        );
        setState(() => _delta = next);
        widget.onChanged(next);
      },
      onPanEnd: (_) {
        setState(() => _delta = Offset.zero);
        widget.onChanged(Offset.zero);
      },
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white54),
        ),
        child: Center(
          child: Transform.translate(
            offset: _delta * 30,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorldTri {
  _WorldTri(this.a, this.b, this.c, this.color);
  final Vector3 a, b, c;
  final Color color;
}

class _Home3dPainter extends CustomPainter {
  _Home3dPainter({
    required this.plan,
    required this.catalog,
    required this.meshes,
    required this.mode,
    required this.yaw,
    required this.pitch,
    required this.distance,
    required this.target,
    required this.eye,
    required this.lookYaw,
    required this.lookPitch,
    required this.lightIntensity,
    required this.ambient,
    required this.isDark,
  });

  final FloorPlan plan;
  final Map<String, CatalogItem> catalog;
  final Map<String, ObjMesh?> meshes;
  final _ViewMode mode;
  final double yaw, pitch, distance;
  final Offset target;
  final Vector3 eye;
  final double lookYaw, lookPitch;
  final double lightIntensity, ambient;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = isDark ? const Color(0xFF141614) : const Color(0xFFD5DDD6),
    );

    final light = Vector3(0.4, 0.9, 0.25)..normalize();
    final world = <_WorldTri>[];
    final floorY = plan.activeLevel.elevationCm;
    final b = plan.bounds.inflate(24);

    _quad(
      world,
      Vector3(b.left, floorY, b.top),
      Vector3(b.right, floorY, b.top),
      Vector3(b.right, floorY, b.bottom),
      Vector3(b.left, floorY, b.bottom),
      const Color(0xFFE9E3D7),
      light,
    );

    for (final w in plan.walls) {
      _wall(world, w, floorY, 250, light);
    }
    for (final s in plan.stairs) {
      _stairs(world, s, floorY, light);
    }
    for (final f in plan.furniture) {
      final item = catalog[f.catalogId];
      final ww = f.widthCm ?? item?.widthCm ?? 60;
      final dd = f.depthCm ?? item?.depthCm ?? 60;
      final hh = item?.heightCm ?? 80;
      final mesh = item == null ? null : meshes[item.id];
      final elev = floorY + f.elevationCm;
      final rot = f.rotationDeg * math.pi / 180;
      if (mesh != null) {
        _mesh(world, mesh, f.xCm, elev, f.yCm, ww, hh, dd, rot, HmColors.spruceSoft, light);
      } else {
        _box(world, f.xCm, elev, f.yCm, ww, hh, dd, rot, HmColors.spruceSoft, light);
      }
    }

    final cam = _cameraBasis();
    final camPos = cam.$1;
    final right = cam.$2;
    final up = cam.$3;
    final forward = cam.$4;
    final focal = size.shortestSide * 0.9;

    final drawn = <({Offset a, Offset b, Offset c, double z, Color color})>[];
    for (final t in world) {
      final pa = _project(t.a, camPos, right, up, forward, focal, size);
      final pb = _project(t.b, camPos, right, up, forward, focal, size);
      final pc = _project(t.c, camPos, right, up, forward, focal, size);
      if (pa == null || pb == null || pc == null) continue;
      drawn.add((a: pa.$1, b: pb.$1, c: pc.$1, z: (pa.$2 + pb.$2 + pc.$2) / 3, color: t.color));
    }
    drawn.sort((a, b) => b.z.compareTo(a.z));

    for (final t in drawn) {
      final path = Path()
        ..moveTo(t.a.dx, t.a.dy)
        ..lineTo(t.b.dx, t.b.dy)
        ..lineTo(t.c.dx, t.c.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = t.color);
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }
  }

  (Vector3, Vector3, Vector3, Vector3) _cameraBasis() {
    if (mode == _ViewMode.orbit) {
      final cy = math.cos(yaw), sy = math.sin(yaw);
      final cp = math.cos(pitch), sp = math.sin(pitch);
      final pos = Vector3(
        target.dx + distance * sy * cp,
        distance * sp + 80,
        target.dy + distance * cy * cp,
      );
      final forward = (Vector3(target.dx, 40, target.dy) - pos)..normalize();
      final right = forward.cross(Vector3(0, 1, 0))..normalize();
      final up = right.cross(forward)..normalize();
      return (pos, right, up, forward);
    }
    final pos = eye.clone();
    final cy = math.cos(lookYaw), sy = math.sin(lookYaw);
    final cp = math.cos(lookPitch), sp = math.sin(lookPitch);
    final forward = Vector3(sy * cp, sp, -cy * cp)..normalize();
    final right = forward.cross(Vector3(0, 1, 0))..normalize();
    final up = right.cross(forward)..normalize();
    return (pos, right, up, forward);
  }

  (Offset, double)? _project(
    Vector3 p,
    Vector3 cam,
    Vector3 right,
    Vector3 up,
    Vector3 forward,
    double focal,
    Size size,
  ) {
    final rel = p - cam;
    final z = rel.dot(forward);
    if (z < 20) return null;
    final x = rel.dot(right);
    final y = rel.dot(up);
    final sx = size.width / 2 + x * focal / z;
    final sy = size.height / 2 - y * focal / z;
    return (Offset(sx, sy), z);
  }

  void _tri(
    List<_WorldTri> out,
    Vector3 a,
    Vector3 b,
    Vector3 c,
    Color base,
    Vector3 light,
  ) {
    final n = (b - a).cross(c - a);
    if (n.length2 < 1e-8) return;
    n.normalize();
    final shade =
        (ambient + lightIntensity * math.max(0.0, n.dot(light))).clamp(0.18, 1.0);
    out.add(
      _WorldTri(
        a,
        b,
        c,
        Color.fromARGB(
          255,
          ((base.r * 255.0) * shade).round().clamp(0, 255),
          ((base.g * 255.0) * shade).round().clamp(0, 255),
          ((base.b * 255.0) * shade).round().clamp(0, 255),
        ),
      ),
    );
  }

  void _quad(
    List<_WorldTri> out,
    Vector3 a,
    Vector3 b,
    Vector3 c,
    Vector3 d,
    Color base,
    Vector3 light,
  ) {
    _tri(out, a, b, c, base, light);
    _tri(out, a, c, d, base, light);
  }

  void _wall(List<_WorldTri> out, Wall w, double y0, double h, Vector3 light) {
    final a0 = Vector3(w.start.dx, y0, w.start.dy);
    final b0 = Vector3(w.end.dx, y0, w.end.dy);
    final a1 = Vector3(w.start.dx, y0 + h, w.start.dy);
    final b1 = Vector3(w.end.dx, y0 + h, w.end.dy);
    _quad(out, a0, b0, b1, a1, const Color(0xFFD2C9BB), light);
  }

  void _stairs(List<_WorldTri> out, StairFlight s, double y0, Vector3 light) {
    final steps = math.max(4, s.steps);
    final stepD = s.depthCm / steps;
    const rise = 280.0;
    final stepH = rise / steps;
    final rad = s.rotationDeg * math.pi / 180;
    for (var i = 0; i < steps; i++) {
      final localZ = -s.depthCm / 2 + stepD * (i + 0.5);
      final cx = s.xCm + localZ * math.sin(rad);
      final cz = s.yCm + localZ * math.cos(rad);
      _box(
        out,
        cx,
        y0 + stepH * i,
        cz,
        s.widthCm,
        stepH * 0.9,
        stepD * 0.9,
        rad,
        const Color(0xFFB9A88E),
        light,
      );
    }
  }

  void _box(
    List<_WorldTri> out,
    double x,
    double y,
    double z,
    double w,
    double h,
    double d,
    double rot,
    Color color,
    Vector3 light,
  ) {
    final hw = w / 2, hd = d / 2;
    final c = <Vector3>[];
    for (final p in [
      [-hw, 0.0, -hd],
      [hw, 0.0, -hd],
      [hw, 0.0, hd],
      [-hw, 0.0, hd],
      [-hw, h, -hd],
      [hw, h, -hd],
      [hw, h, hd],
      [-hw, h, hd],
    ]) {
      final rx = p[0] * math.cos(rot) - p[2] * math.sin(rot);
      final rz = p[0] * math.sin(rot) + p[2] * math.cos(rot);
      c.add(Vector3(x + rx, y + p[1], z + rz));
    }
    for (final f in const [
      [0, 1, 2, 3],
      [4, 7, 6, 5],
      [0, 4, 5, 1],
      [1, 5, 6, 2],
      [2, 6, 7, 3],
      [3, 7, 4, 0],
    ]) {
      _quad(out, c[f[0]], c[f[1]], c[f[2]], c[f[3]], color, light);
    }
  }

  void _mesh(
    List<_WorldTri> out,
    ObjMesh mesh,
    double x,
    double y,
    double z,
    double w,
    double h,
    double d,
    double rot,
    Color color,
    Vector3 light,
  ) {
    Vector3 xf(Vector3 p) {
      final lx = p.x * w;
      final ly = p.y * h;
      final lz = p.z * d;
      final rx = lx * math.cos(rot) - lz * math.sin(rot);
      final rz = lx * math.sin(rot) + lz * math.cos(rot);
      return Vector3(x + rx, y + ly, z + rz);
    }

    for (final t in mesh.triangles) {
      _tri(
        out,
        xf(mesh.positions[t[0]]),
        xf(mesh.positions[t[1]]),
        xf(mesh.positions[t[2]]),
        color,
        light,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Home3dPainter old) => true;
}
