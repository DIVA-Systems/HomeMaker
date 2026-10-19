import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/app_settings.dart';
import '../../data/overlay_store.dart';
import '../../models/floor_plan.dart';
import '../../models/plan_overlay.dart';
import '../../state/providers.dart';
import '../../theme/hm_colors.dart';
import '../../units/length_units.dart';

/// SH3D-style Background Image wizard: pick → scale → place.
class OverlayWizardScreen extends ConsumerStatefulWidget {
  const OverlayWizardScreen({super.key, required this.planSeed});

  final FloorPlan planSeed;

  @override
  ConsumerState<OverlayWizardScreen> createState() =>
      _OverlayWizardScreenState();
}

class _OverlayWizardScreenState extends ConsumerState<OverlayWizardScreen> {
  int _step = 0;
  ui.Image? _preview;
  String? _fileName;
  int _w = 0;
  int _h = 0;
  Offset? _p1;
  Offset? _p2;
  double _distanceCm = 300; // default 3 m
  double _opacity = 0.55;
  Offset _origin = const Offset(40, 40);

  EditorNotifier get _editor =>
      ref.read(editorProvider(widget.planSeed).notifier);

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 4096,
      imageQuality: 92,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final store = OverlayStore();
    final name = await store.savePickedBytes(
      bytes,
      picked.name.isEmpty ? 'plan.png' : picked.name,
    );
    setState(() {
      _preview = frame.image;
      _fileName = name;
      _w = frame.image.width;
      _h = frame.image.height;
      _p1 = Offset(_w * 0.15, _h * 0.5);
      _p2 = Offset(_w * 0.85, _h * 0.5);
      _step = 1;
    });
  }

  void _finish() {
    if (_fileName == null || _preview == null || _p1 == null || _p2 == null) {
      return;
    }
    final overlay = PlanOverlay(
      imageFileName: _fileName!,
      imageWidthPx: _w,
      imageHeightPx: _h,
      scaleDistanceCm: _distanceCm.clamp(10, 50000),
      scaleStartPx: _p1!,
      scaleEndPx: _p2!,
      originPlanCm: _origin,
      opacity: _opacity,
      visible: true,
    );
    _editor.setOverlay(overlay);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(appSettingsProvider).unitSystem;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _step == 0
              ? 'Import floor plan'
              : _step == 1
                  ? 'Set scale'
                  : 'Place & opacity',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              _step == 0
                  ? 'Upload a photo or scan of your floor plan (SH3D-style overlay).'
                  : _step == 1
                      ? 'Tap two points on a wall whose real length you know.'
                      : 'Drag the overlay on the plan, then adjust opacity.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(child: _buildStep(units)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  if (_step == 0)
                    FilledButton(
                      onPressed: _pick,
                      style: FilledButton.styleFrom(
                        backgroundColor: HmColors.spruce,
                      ),
                      child: const Text('Choose image'),
                    )
                  else if (_step < 2)
                    FilledButton(
                      onPressed: (_p1 != null && _p2 != null)
                          ? () => setState(() => _step = 2)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: HmColors.spruce,
                      ),
                      child: const Text('Next'),
                    )
                  else
                    FilledButton(
                      onPressed: _finish,
                      style: FilledButton.styleFrom(
                        backgroundColor: HmColors.spruce,
                      ),
                      child: const Text('Add overlay'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(LengthUnitSystem units) {
    if (_step == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 64, color: HmColors.spruceSoft),
            const SizedBox(height: 12),
            Text(
              'JPG or PNG from camera roll',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    if (_step == 1 && _preview != null) {
      return Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final scale = (c.maxWidth / _w).clamp(0.01, 4.0);
                return GestureDetector(
                  onTapDown: (d) {
                    final local = d.localPosition;
                    final img = Offset(local.dx / scale, local.dy / scale);
                    setState(() {
                      if (_p1 == null || (_p1 != null && _p2 != null)) {
                        _p1 = img;
                        _p2 = null;
                      } else {
                        _p2 = img;
                      }
                    });
                  },
                  child: CustomPaint(
                    size: Size(_w * scale, _h * scale),
                    painter: _ScalePainter(
                      image: _preview!,
                      scale: scale,
                      p1: _p1,
                      p2: _p2,
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('Length', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoTextField(
                    placeholder: units == LengthUnitSystem.metric
                        ? 'e.g. 3.5 (meters)'
                        : 'e.g. 12 (feet)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) {
                      final n = double.tryParse(v.replaceAll(',', '.'));
                      if (n == null || n <= 0) return;
                      setState(() {
                        _distanceCm = units == LengthUnitSystem.metric
                            ? Units.metersToCm(n)
                            : Units.feetToCm(n);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Using ${Units.formatLength(_distanceCm, units)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    // Step 2 — opacity + origin nudge
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_preview != null)
          AspectRatio(
            aspectRatio: _w / _h,
            child: Opacity(
              opacity: _opacity,
              child: RawImage(image: _preview, fit: BoxFit.contain),
            ),
          ),
        const SizedBox(height: 16),
        Text('Opacity', style: Theme.of(context).textTheme.titleSmall),
        Slider(
          value: _opacity,
          onChanged: (v) => setState(() => _opacity = v),
          activeColor: HmColors.spruce,
        ),
        Text('Position on plan (cm from origin)',
            style: Theme.of(context).textTheme.titleSmall),
        Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                placeholder: 'X',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: (v) {
                  final n = double.tryParse(v);
                  if (n != null) setState(() => _origin = Offset(n, _origin.dy));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CupertinoTextField(
                placeholder: 'Y',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: (v) {
                  final n = double.tryParse(v);
                  if (n != null) setState(() => _origin = Offset(_origin.dx, n));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tip: after adding, draw walls along the overlay. '
          'You can hide or remove it from the toolbar.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ScalePainter extends CustomPainter {
  _ScalePainter({
    required this.image,
    required this.scale,
    required this.p1,
    required this.p2,
  });

  final ui.Image image;
  final double scale;
  final Offset? p1;
  final Offset? p2;

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image,
      fit: BoxFit.fill,
    );
    void mark(Offset? p, Color c) {
      if (p == null) return;
      final s = p * scale;
      canvas.drawCircle(s, 8, Paint()..color = c);
      canvas.drawCircle(
        s,
        8,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    mark(p1, HmColors.spruce);
    mark(p2, HmColors.clay);
    if (p1 != null && p2 != null) {
      canvas.drawLine(
        p1! * scale,
        p2! * scale,
        Paint()
          ..color = HmColors.spruce
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScalePainter old) => true;
}
