import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/models/sketch_tool.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

SketchRectangle _rect({String? id, Rect? rect}) => SketchRectangle.create(
      id: id,
      rect: rect ?? const Rect.fromLTWH(0, 0, 10, 10),
    );

void main() {
  group('SketchController.add / remove', () {
    test('add appends element and bumps paintGen', () {
      final c = SketchController();
      final gen0 = c.paintGen;
      c.add(_rect(id: 'a'));
      expect(c.elements.map((e) => e.id), ['a']);
      expect(c.paintGen, greaterThan(gen0));
    });

    test('addAll is a no-op for empty input', () {
      final c = SketchController();
      final gen0 = c.paintGen;
      c.addAll(const <SketchElement>[]);
      expect(c.elements, isEmpty);
      expect(c.paintGen, gen0);
    });

    test('remove drops the element and its selection', () {
      final c = SketchController()..add(_rect(id: 'a'));
      c.select('a');
      expect(c.isSelected('a'), isTrue);
      c.remove('a');
      expect(c.elements, isEmpty);
      expect(c.isSelected('a'), isFalse);
    });

    test('removeSelected removes all selected elements', () {
      final c = SketchController()
        ..add(_rect(id: 'a'))
        ..add(_rect(id: 'b'))
        ..add(_rect(id: 'c'));
      c.selectMany({'a', 'c'});
      final removed = c.removeSelected();
      expect(removed, 2);
      expect(c.elements.map((e) => e.id), ['b']);
      expect(c.hasSelection, isFalse);
    });
  });

  group('SketchController.translateSelected', () {
    test('moves only selected elements', () {
      final c = SketchController()
        ..add(_rect(id: 'a', rect: const Rect.fromLTWH(0, 0, 10, 10)))
        ..add(_rect(id: 'b', rect: const Rect.fromLTWH(100, 0, 10, 10)));
      c.select('a');
      c.translateSelected(const Offset(5, 7));
      expect(c.elements[0].bounds, const Rect.fromLTWH(5, 7, 10, 10));
      expect(c.elements[1].bounds, const Rect.fromLTWH(100, 0, 10, 10));
    });
  });

  group('SketchController.undo / redo', () {
    test('undoes the most recent mutation', () {
      final c = SketchController()..add(_rect(id: 'a'));
      c.add(_rect(id: 'b'));
      expect(c.canUndo, isTrue);
      c.undo();
      expect(c.elements.map((e) => e.id), ['a']);
      c.redo();
      expect(c.elements.map((e) => e.id), ['a', 'b']);
    });

    test('selection is part of the snapshot', () {
      final c = SketchController()..add(_rect(id: 'a'));
      c.select('a');
      c.add(_rect(id: 'b'));
      c.undo();
      expect(c.isSelected('a'), isTrue);
    });
  });

  group('SketchController.currentTool', () {
    test('switching away from select clears selection', () {
      final c = SketchController()..add(_rect(id: 'a'));
      c.select('a');
      c.currentTool = SketchTool.rectangle;
      expect(c.isSelected('a'), isFalse);
    });

    test('staying on select preserves selection', () {
      final c = SketchController()..add(_rect(id: 'a'));
      c.select('a');
      c.currentTool = SketchTool.select;
      expect(c.isSelected('a'), isTrue);
    });
  });

  group('SketchController.selectInRegion', () {
    test('selects elements whose bounds intersect the region', () {
      final c = SketchController()
        ..add(_rect(id: 'in', rect: const Rect.fromLTWH(5, 5, 5, 5)))
        ..add(_rect(id: 'out', rect: const Rect.fromLTWH(100, 100, 5, 5)));
      c.selectInRegion(const Rect.fromLTWH(0, 0, 50, 50));
      expect(c.selectedIds, {'in'});
    });
  });

  group('SketchController.currentStyle', () {
    test('updating style notifies listeners', () {
      final c = SketchController();
      var notified = 0;
      c.addListener(() => notified++);
      c.currentStyle =
          const SketchStyle(strokeColor: Color(0xFFFF0000));
      expect(notified, 1);
    });
  });
}
