import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:homemaker/geometry/room_detection.dart';
import 'package:homemaker/models/floor_plan.dart';

void main() {
  test('detects a rectangular room', () {
    const o = 0.0;
    const w = 500.0;
    const d = 400.0;
    final walls = [
      Wall(id: '1', start: const Offset(o, o), end: const Offset(o + w, o)),
      Wall(id: '2', start: const Offset(o + w, o), end: const Offset(o + w, o + d)),
      Wall(id: '3', start: const Offset(o + w, o + d), end: const Offset(o, o + d)),
      Wall(id: '4', start: const Offset(o, o + d), end: const Offset(o, o)),
    ];
    final rooms = detectRooms(walls);
    expect(rooms, isNotEmpty);
    expect(rooms.first.areaM2, closeTo(20.0, 0.5)); // 5m × 4m
  });
}
