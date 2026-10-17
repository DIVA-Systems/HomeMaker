import 'dart:math' as math;
import 'dart:ui';

import '../models/floor_plan.dart';

const _joinTol = 18.0; // cm — snap endpoints into a graph

/// Detect closed rooms from wall segments (SH3D-style floor fills).
List<PlanRoom> detectRooms(List<Wall> walls, {Map<String, String>? names}) {
  if (walls.length < 3) return const [];

  // Build undirected graph of snapped nodes
  final nodes = <Offset>[];
  int nodeIndex(Offset p) {
    for (var i = 0; i < nodes.length; i++) {
      if ((nodes[i] - p).distance <= _joinTol) return i;
    }
    nodes.add(p);
    return nodes.length - 1;
  }

  final edges = <_Edge>[];
  for (final w in walls) {
    final a = nodeIndex(w.start);
    final b = nodeIndex(w.end);
    if (a == b) continue;
    edges.add(_Edge(a, b, w.id));
  }

  // Adjacency
  final adj = <int, List<int>>{};
  for (final e in edges) {
    adj.putIfAbsent(e.a, () => []).add(e.b);
    adj.putIfAbsent(e.b, () => []).add(e.a);
  }

  // Find minimal cycles via left-face walk
  final usedDirected = <String>{};
  final cycles = <List<int>>[];

  String dirKey(int from, int to) => '$from>$to';

  for (final e in edges) {
    for (final startPair in [(e.a, e.b), (e.b, e.a)]) {
      final start = startPair.$1;
      final next0 = startPair.$2;
      if (usedDirected.contains(dirKey(start, next0))) continue;

      final cycle = <int>[start];
      var prev = start;
      var cur = next0;
      usedDirected.add(dirKey(prev, cur));
      var guard = 0;
      while (cur != start && guard < 64) {
        cycle.add(cur);
        final neighbors = adj[cur] ?? const <int>[];
        if (neighbors.isEmpty) break;
        // Pick next with smallest left turn (CCW) relative to incoming
        final incoming = nodes[cur] - nodes[prev];
        var best = neighbors.first;
        var bestAng = double.infinity;
        for (final n in neighbors) {
          if (n == prev && neighbors.length > 1) continue;
          final outgoing = nodes[n] - nodes[cur];
          final ang = _relativeAngle(incoming, outgoing);
          if (ang < bestAng) {
            bestAng = ang;
            best = n;
          }
        }
        prev = cur;
        cur = best;
        final key = dirKey(prev, cur);
        if (usedDirected.contains(key) && cur != start) break;
        usedDirected.add(key);
        guard++;
      }

      if (cur == start && cycle.length >= 3) {
        // Normalize rotation & drop duplicates
        final area = _signedArea(cycle.map((i) => nodes[i]).toList());
        if (area.abs() < 5000) continue; // tiny / degenerate (~0.5 m²)
        // Prefer CCW
        final ordered = area < 0 ? cycle.reversed.toList() : cycle;
        final sig = _cycleSignature(ordered);
        if (cycles.any((c) => _cycleSignature(c) == sig)) continue;
        cycles.add(ordered);
      }
    }
  }

  // Deduplicate by similar centroid
  final rooms = <PlanRoom>[];
  var idx = 1;
  for (final c in cycles) {
    final poly = c.map((i) => nodes[i]).toList();
    final room = PlanRoom(
      id: 'room_${_polyHash(poly)}',
      name: names?['room_${_polyHash(poly)}'] ?? 'Room $idx',
      polygon: poly,
    );
    // Skip if nearly same as existing
    final dup = rooms.any(
      (r) => (r.centroid - room.centroid).distance < 40 &&
          (r.areaM2 - room.areaM2).abs() < 0.5,
    );
    if (dup) continue;
    // Skip outer unbounded face (largest that contains others) — keep interior rooms
    rooms.add(room);
    idx++;
  }

  // Drop the single largest if it looks like exterior hull of everything
  if (rooms.length >= 2) {
    rooms.sort((a, b) => b.areaM2.compareTo(a.areaM2));
    final largest = rooms.first;
    final othersInside = rooms.skip(1).every(
          (r) => _pointInPoly(r.centroid, largest.polygon),
        );
    if (othersInside && largest.areaM2 > rooms[1].areaM2 * 1.5) {
      rooms.removeAt(0);
    }
  }

  rooms.sort((a, b) => a.name.compareTo(b.name));
  return rooms;
}

class _Edge {
  _Edge(this.a, this.b, this.wallId);
  final int a;
  final int b;
  final String wallId;
}

double _relativeAngle(Offset incoming, Offset outgoing) {
  final a1 = math.atan2(incoming.dy, incoming.dx);
  final a2 = math.atan2(outgoing.dy, outgoing.dx);
  var d = a2 - a1;
  while (d <= -math.pi) {
    d += 2 * math.pi;
  }
  while (d > math.pi) {
    d -= 2 * math.pi;
  }
  // Map so leftmost turn is smallest positive
  return d < 0 ? d + 2 * math.pi : d;
}

double _signedArea(List<Offset> poly) {
  var sum = 0.0;
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i];
    final b = poly[(i + 1) % poly.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum / 2;
}

String _cycleSignature(List<int> c) {
  if (c.isEmpty) return '';
  final rot = List<int>.from(c);
  final minI = rot.indexOf(rot.reduce(math.min));
  final norm = [...rot.sublist(minI), ...rot.sublist(0, minI)];
  final rev = norm.reversed.toList();
  final a = norm.join(',');
  final b = rev.join(',');
  return a.compareTo(b) <= 0 ? a : b;
}

String _polyHash(List<Offset> poly) {
  final cx = poly.fold<double>(0, (s, p) => s + p.dx) / poly.length;
  final cy = poly.fold<double>(0, (s, p) => s + p.dy) / poly.length;
  return '${cx.round()}_${cy.round()}_${poly.length}';
}

bool _pointInPoly(Offset p, List<Offset> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final pi = poly[i];
    final pj = poly[j];
    final intersect = ((pi.dy > p.dy) != (pj.dy > p.dy)) &&
        (p.dx <
            (pj.dx - pi.dx) * (p.dy - pi.dy) / ((pj.dy - pi.dy) + 1e-9) + pi.dx);
    if (intersect) inside = !inside;
  }
  return inside;
}
