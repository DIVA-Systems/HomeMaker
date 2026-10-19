import 'dart:ui';

/// Floor-plan background overlay — mirrors SH3D `BackgroundImage`:
/// image + scale segment (two points + real distance) + origin in plan cm.
class PlanOverlay {
  PlanOverlay({
    required this.imageFileName,
    required this.imageWidthPx,
    required this.imageHeightPx,
    this.scaleDistanceCm = 100,
    this.scaleStartPx = Offset.zero,
    Offset? scaleEndPx,
    this.originPlanCm = Offset.zero,
    this.opacity = 0.55,
    this.visible = true,
  }) : scaleEndPx = scaleEndPx ?? Offset(imageWidthPx.toDouble(), 0);

  /// Stored under app documents `overlays/<fileName>`.
  final String imageFileName;
  final int imageWidthPx;
  final int imageHeightPx;

  /// Real-world length of the measured segment (cm).
  double scaleDistanceCm;
  Offset scaleStartPx;
  Offset scaleEndPx;

  /// Plan-space position of the image's top-left corner (cm).
  Offset originPlanCm;
  double opacity;
  bool visible;

  double get scaleSegmentPx => (scaleEndPx - scaleStartPx).distance.clamp(1.0, 1e9);

  /// Centimeters per image pixel (SH3D scale).
  double get cmPerPixel => scaleDistanceCm / scaleSegmentPx;

  Size get planSizeCm => Size(
        imageWidthPx * cmPerPixel,
        imageHeightPx * cmPerPixel,
      );

  Rect get planRectCm => Rect.fromLTWH(
        originPlanCm.dx,
        originPlanCm.dy,
        planSizeCm.width,
        planSizeCm.height,
      );

  PlanOverlay copy() => PlanOverlay(
        imageFileName: imageFileName,
        imageWidthPx: imageWidthPx,
        imageHeightPx: imageHeightPx,
        scaleDistanceCm: scaleDistanceCm,
        scaleStartPx: scaleStartPx,
        scaleEndPx: scaleEndPx,
        originPlanCm: originPlanCm,
        opacity: opacity,
        visible: visible,
      );

  Map<String, dynamic> toJson() => {
        'imageFileName': imageFileName,
        'imageWidthPx': imageWidthPx,
        'imageHeightPx': imageHeightPx,
        'scaleDistanceCm': scaleDistanceCm,
        'sx': scaleStartPx.dx,
        'sy': scaleStartPx.dy,
        'ex': scaleEndPx.dx,
        'ey': scaleEndPx.dy,
        'ox': originPlanCm.dx,
        'oy': originPlanCm.dy,
        'opacity': opacity,
        'visible': visible,
      };

  factory PlanOverlay.fromJson(Map<String, dynamic> json) => PlanOverlay(
        imageFileName: json['imageFileName'] as String,
        imageWidthPx: (json['imageWidthPx'] as num).toInt(),
        imageHeightPx: (json['imageHeightPx'] as num).toInt(),
        scaleDistanceCm: (json['scaleDistanceCm'] as num?)?.toDouble() ?? 100,
        scaleStartPx: Offset(
          (json['sx'] as num?)?.toDouble() ?? 0,
          (json['sy'] as num?)?.toDouble() ?? 0,
        ),
        scaleEndPx: Offset(
          (json['ex'] as num?)?.toDouble() ?? 100,
          (json['ey'] as num?)?.toDouble() ?? 0,
        ),
        originPlanCm: Offset(
          (json['ox'] as num?)?.toDouble() ?? 0,
          (json['oy'] as num?)?.toDouble() ?? 0,
        ),
        opacity: (json['opacity'] as num?)?.toDouble() ?? 0.55,
        visible: json['visible'] as bool? ?? true,
      );
}
