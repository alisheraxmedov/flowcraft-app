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

  group('SketchController drag sessions', () {
    test('a session that never mutates leaves history untouched', () {
      final c = SketchController(initialElements: [_rect(id: 'a')]);
      c.select('a');

      // What a plain click-to-select does: opens a move session, moves
      // nothing, closes it. Pushing eagerly here made `canUndo` go true and
      // the user's first undo visibly do nothing.
      c.beginDragSession();
      c.endDragSession();

      expect(c.canUndo, isFalse);
    });

    test('a move drag collapses into exactly one entry', () {
      final c = SketchController(initialElements: [_rect(id: 'a')]);
      c.select('a');

      c.beginDragSession();
      for (var i = 0; i < 3; i++) {
        c.translateSelected(const Offset(5, 0));
      }
      c.endDragSession();

      expect(c.elements.single.bounds, const Rect.fromLTWH(15, 0, 10, 10));
      c.undo();
      expect(c.elements.single.bounds, const Rect.fromLTWH(0, 0, 10, 10));
      expect(c.canUndo, isFalse);
    });

    test('a resize drag collapses into exactly one entry', () {
      final c = SketchController(initialElements: [_rect(id: 'a')]);
      c.select('a');

      c.beginDragSession();
      for (final w in <double>[20, 30, 40]) {
        c.resizeElement('a', Rect.fromLTWH(0, 0, w, w));
      }
      c.endDragSession();

      expect(c.elements.single.bounds, const Rect.fromLTWH(0, 0, 40, 40));
      c.undo();
      expect(c.elements.single.bounds, const Rect.fromLTWH(0, 0, 10, 10));
      expect(c.canUndo, isFalse);
    });

    test('a session around a no-op resize leaves history untouched', () {
      final c = SketchController(initialElements: [_rect(id: 'a')]);

      // The properties panel brackets `resizeElement` the same way; an
      // element with no rect can't resize, so nothing should be recorded.
      c.beginDragSession();
      c.resizeElement('missing', const Rect.fromLTWH(0, 0, 50, 50));
      c.endDragSession();

      expect(c.canUndo, isFalse);
    });
  });

  group('SketchController.applyStyleToSelected', () {
    const red = Color(0xFFFF0000);
    final defaultStroke = const SketchStyle().strokeColor;

    test('restyles every selected element in one history entry', () {
      final c = SketchController(
        initialElements: [_rect(id: 'a'), _rect(id: 'b'), _rect(id: 'c')],
      );
      c.selectMany({'a', 'b'});
      expect(c.canUndo, isFalse);

      final changed =
          c.applyStyleToSelected((s) => s.copyWith(strokeColor: red));

      expect(changed, 2);
      expect(c.elements[0].style.strokeColor, red);
      expect(c.elements[1].style.strokeColor, red);
      expect(c.elements[2].style.strokeColor, defaultStroke);

      // One entry for the whole batch — not one per element.
      c.undo();
      expect(
        c.elements.map((e) => e.style.strokeColor),
        everyElement(defaultStroke),
      );
      expect(c.canUndo, isFalse);
    });

    test('preserves per-element geometry and text', () {
      final c = SketchController(
        initialElements: [
          SketchRectangle.create(
            id: 'a',
            rect: const Rect.fromLTWH(3, 4, 20, 30),
            text: 'Label',
          ),
        ],
      );
      c.select('a');
      c.applyStyleToSelected((s) => s.copyWith(strokeColor: red));

      final updated = c.elements.single as SketchRectangle;
      expect(updated.rect, const Rect.fromLTWH(3, 4, 20, 30));
      expect(updated.text, 'Label');
      expect(updated.style.strokeColor, red);
    });

    test('is a no-op without a selection', () {
      final c = SketchController(initialElements: [_rect(id: 'a')]);
      final gen0 = c.paintGen;

      expect(c.applyStyleToSelected((s) => s.copyWith(strokeColor: red)), 0);
      expect(c.elements.single.style.strokeColor, defaultStroke);
      expect(c.paintGen, gen0);
      expect(c.canUndo, isFalse);
    });

    test('is a no-op when the transform changes nothing', () {
      final c = SketchController(initialElements: [_rect(id: 'a')]);
      c.select('a');
      final gen0 = c.paintGen;

      expect(c.applyStyleToSelected((s) => s), 0);
      expect(c.paintGen, gen0);
      expect(c.canUndo, isFalse);
    });

    test('collapses a whole drag session into one undo', () {
      final c = SketchController(initialElements: [_rect(id: 'a')]);
      c.select('a');

      // How the toolbar's stroke-width / roughness sliders drive it: one
      // call per tick, bracketed by begin/endDragSession.
      c.beginDragSession();
      for (final w in <double>[3, 4, 5]) {
        c.applyStyleToSelected((s) => s.copyWith(strokeWidth: w));
      }
      c.endDragSession();

      expect(c.elements.single.style.strokeWidth, 5);
      c.undo();
      expect(c.elements.single.style.strokeWidth, const SketchStyle().strokeWidth);
      expect(c.canUndo, isFalse);
    });
  });

  group('loadScene', () {
    test('discards history, so undo cannot pull back the previous scene', () {
      final c = SketchController(initialElements: [_rect(id: 'old')]);
      c.select('old');
      c.add(_rect(id: 'also-old'));
      expect(c.canUndo, isTrue);

      c.loadScene([_rect(id: 'new')]);

      expect(c.elements.single.id, 'new');
      expect(c.selectedIds, isEmpty);
      // The point of the method: opening a saved project must not leave the
      // outgoing project's elements one Ctrl+Z away, because autosave would
      // then write them into the newly-opened project's file.
      expect(c.canUndo, isFalse);
      expect(c.canRedo, isFalse);
    });

    test('abandons an in-flight drag and text edit', () {
      final c = SketchController(initialElements: [_rect(id: 'old')]);
      c.select('old');
      c.beginTextEdit(elementId: 'old');
      c.beginDragSession();

      c.loadScene([_rect(id: 'new')]);

      expect(c.editingElementId, isNull);
      expect(c.editingCanvasPosition, isNull);
      // The armed drag snapshot belonged to the outgoing scene; a mutation
      // on the new one must not resurrect it as an undo entry.
      c.select('new');
      c.translateSelected(const Offset(5, 5));
      c.undo();
      expect(c.elements.single.id, 'new');
      expect(c.canUndo, isFalse);
    });
  });
}
