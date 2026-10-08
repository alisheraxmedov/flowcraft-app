import 'dart:ui';

import 'package:flowcraft/core/domain/graph_layout.dart';
import 'package:flutter_test/flutter_test.dart';

const _box = Size(100, 40);

Map<String, Offset> _layout(
  List<String> ids,
  List<(String, String)> edges, {
  LayoutDirection direction = LayoutDirection.tb,
}) => GraphLayout.layout(
  ids: ids,
  sizes: {for (final id in ids) id: _box},
  edges: edges,
  direction: direction,
);

void main() {
  const chain = [('a', 'b'), ('b', 'c')];

  test('a chain gets three ranks with increasing y in TB', () {
    final p = _layout(['a', 'b', 'c'], chain);

    expect(p['a']!.dy, lessThan(p['b']!.dy));
    expect(p['b']!.dy, lessThan(p['c']!.dy));
    expect(p['b']!.dy - p['a']!.dy, 40 + 96);
  });

  test('LR ranks along x', () {
    final p = _layout(['a', 'b', 'c'], chain, direction: LayoutDirection.lr);

    expect(p['a']!.dx, lessThan(p['b']!.dx));
    expect(p['b']!.dx, lessThan(p['c']!.dx));
    expect(p['a']!.dy, p['c']!.dy);
  });

  test('BT reverses TB', () {
    final p = _layout(['a', 'b', 'c'], chain, direction: LayoutDirection.bt);

    expect(p['a']!.dy, greaterThan(p['b']!.dy));
    expect(p['b']!.dy, greaterThan(p['c']!.dy));
  });

  test('RL mirrors LR', () {
    final p = _layout(['a', 'b', 'c'], chain, direction: LayoutDirection.rl);

    expect(p['a']!.dx, greaterThan(p['b']!.dx));
    expect(p['b']!.dx, greaterThan(p['c']!.dx));
  });

  test('a cycle terminates and gives distinct ranks', () {
    final p = _layout(['a', 'b', 'c'], [...chain, ('c', 'a')]);

    expect({p['a']!.dy, p['b']!.dy, p['c']!.dy}, hasLength(3));
  });

  test('a diamond graph has no overlapping boxes', () {
    final p = _layout(
      ['a', 'b', 'c', 'd'],
      [('a', 'b'), ('a', 'c'), ('b', 'd'), ('c', 'd')],
    );

    final rects = [for (final o in p.values) o & _box];
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(rects[i].overlaps(rects[j]), isFalse);
      }
    }
    expect(p['b']!.dy, p['c']!.dy);
    expect(p['d']!.dy, greaterThan(p['b']!.dy));
  });

  test('siblings keep insertion order', () {
    final p = _layout(
      ['r', 'x', 'y', 'z'],
      [('r', 'x'), ('r', 'y'), ('r', 'z')],
    );

    expect(p['x']!.dx, lessThan(p['y']!.dx));
    expect(p['y']!.dx, lessThan(p['z']!.dx));
  });

  test('isolated nodes sit on rank 0 without overlapping', () {
    final p = _layout(['a', 'b', 'i', 'j'], [('a', 'b')]);

    expect(p['i']!.dy, p['a']!.dy);
    expect(p['j']!.dy, p['a']!.dy);
    final rects = [
      for (final id in ['a', 'i', 'j']) p[id]! & _box,
    ];
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(rects[i].overlaps(rects[j]), isFalse);
      }
    }
  });

  test('a 10000-node chain lays out without stack overflow', () {
    final ids = [for (var i = 0; i < 10000; i++) 'n$i'];
    final p = _layout(ids, [
      for (var i = 0; i < 9999; i++) (ids[i], ids[i + 1]),
    ]);
    expect(p.length, 10000);
    expect(p['n0']!.dy, lessThan(p['n9999']!.dy));
  });
}
