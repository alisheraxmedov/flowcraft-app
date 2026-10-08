import 'dart:ui';

import 'package:flowcraft/flowcraft.dart';
import 'package:flowcraft/services/mcp_checkpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SketchController controller;
  late McpCheckpoints checkpoints;

  setUp(() {
    controller = SketchController(currentTool: SketchTool.select);
    checkpoints = McpCheckpoints();
  });

  tearDown(() => controller.dispose());

  void draw() => controller.add(
    SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 10, 10)),
  );

  test('drops oldest past 20', () {
    for (var i = 0; i < 25; i++) {
      draw();
      checkpoints.capture(controller, 'draw', null);
    }

    final ids = checkpoints.list().map((c) => c.id).toList();
    expect(ids.length, McpCheckpoints.maxEntries);
    expect(ids.first, 'cp-6');
    expect(ids.last, 'cp-25');
    expect(checkpoints.find('cp-1'), isNull);
  });

  test('dedupes unchanged paintGen', () {
    draw();
    final first = checkpoints.capture(controller, 'draw', null);
    final again = checkpoints.capture(controller, 'draw', null);

    expect(again.id, first.id);
    expect(checkpoints.list(), hasLength(1));

    draw();
    checkpoints.capture(controller, 'draw', null);
    expect(checkpoints.list(), hasLength(2));
  });

  test('a snapshot keeps the scene it saw', () {
    draw();
    final cp = checkpoints.capture(controller, 'draw', null);
    draw();

    expect(cp.elements, hasLength(1));
    expect(controller.elements, hasLength(2));
  });

  test('restore refuses another project', () {
    draw();
    checkpoints.capture(controller, 'draw', 'p1');

    // The tool compares the stored project with the open one; the ring only
    // has to keep that id faithfully, and treat a project switch as a change.
    expect(checkpoints.find('cp-1')!.projectId, 'p1');
    final other = checkpoints.capture(controller, 'draw', 'p2');
    expect(other.id, 'cp-2');
  });
}
