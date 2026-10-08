import 'dart:convert';
import 'dart:ui';

import 'package:flutter/painting.dart' show Axis;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/serialization/sketch_serializer.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/models/sketch_tool.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

SketchRectangle _rect({String? id, Rect? rect}) => SketchRectangle.create(
  id: id,
  rect: rect ?? const Rect.fromLTWH(0, 0, 10, 10),
);

void main() {
  group('SketchController.addFrame', () {
    test('inserts behind shapes but after earlier frames, one undo entry', () {
      final f1 = SketchFrame.create(
        id: 'f1',
        rect: const Rect.fromLTWH(0, 0, 9, 9),
      );
      final box = SketchRectangle.create(
        id: 'b',
        rect: const Rect.fromLTWH(0, 0, 5, 5),
      );
      final c = SketchController(initialElements: [f1, box]);
      addTearDown(c.dispose);
      c.addFrame(
        SketchFrame.create(id: 'f2', rect: const Rect.fromLTWH(0, 0, 9, 9)),
      );
      expect(c.elements.map((e) => e.id), ['f1', 'f2', 'b']);
      c.undo();
      expect(c.elements.map((e) => e.id), ['f1', 'b']);
    });

    test('currentIcon defaults to database and notifies on change', () {
      final c = SketchController();
      addTearDown(c.dispose);
      var n = 0;
      c.addListener(() => n++);
      expect(c.currentIcon, 'database');
      c.currentIcon = 'cloud';
      c.currentIcon = 'cloud';
      expect(n, 1);
    });
  });

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

  group('SketchController.updateAll', () {
    test('replaces matching elements as one undo entry, returns count', () {
      // Seeded through the constructor, not `add`, so the only history entry
      // in play is the one `updateAll` itself pushes.
      final c = SketchController(
        initialElements: [
          _rect(id: 'a', rect: const Rect.fromLTWH(0, 0, 10, 10)),
          _rect(id: 'b', rect: const Rect.fromLTWH(50, 0, 10, 10)),
        ],
      );
      expect(c.canUndo, isFalse);

      final replaced = c.updateAll([
        _rect(id: 'a', rect: const Rect.fromLTWH(5, 5, 10, 10)),
        _rect(id: 'b', rect: const Rect.fromLTWH(60, 5, 10, 10)),
      ]);

      expect(replaced, 2);
      expect(c.elements[0].bounds.left, 5);
      expect(c.elements[1].bounds.left, 60);

      // The whole batch is a single undo, and one `undo()` restores both.
      expect(c.canUndo, isTrue);
      c.undo();
      expect(c.elements[0].bounds.left, 0);
      expect(c.elements[1].bounds.left, 50);
      expect(c.canUndo, isFalse);
    });

    test('replaces only the matching subset', () {
      final c = SketchController(
        initialElements: [
          _rect(id: 'a', rect: const Rect.fromLTWH(0, 0, 10, 10)),
        ],
      );
      final replaced = c.updateAll([
        _rect(id: 'a', rect: const Rect.fromLTWH(9, 9, 10, 10)),
        _rect(id: 'ghost'),
      ]);

      expect(replaced, 1);
      expect(c.elements.single.bounds.left, 9);
    });

    test('an all-stale batch changes nothing and leaves no undo entry', () {
      final c = SketchController(initialElements: [_rect(id: 'a')]);
      final replaced = c.updateAll([_rect(id: 'ghost')]);

      expect(replaced, 0);
      expect(c.elements.map((e) => e.id), ['a']);
      expect(c.canUndo, isFalse);
    });
  });

  group('SketchController.removeIds', () {
    test('removes matching ids as one undo entry, returns count', () {
      final c = SketchController(
        initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b'),
          _rect(id: 'c'),
        ],
      );
      c.select('a');

      final removed = c.removeIds(['a', 'c', 'ghost']);

      expect(removed, 2);
      expect(c.elements.map((e) => e.id), ['b']);
      // A deleted id must not outlive its element in the selection.
      expect(c.isSelected('a'), isFalse);

      expect(c.canUndo, isTrue);
      c.undo();
      expect(c.elements.map((e) => e.id), ['a', 'b', 'c']);
      expect(c.canUndo, isFalse);
    });

    test('an all-stale delete changes nothing and leaves no undo entry', () {
      final c = SketchController(initialElements: [_rect(id: 'a')]);
      final removed = c.removeIds(['ghost']);

      expect(removed, 0);
      expect(c.elements.map((e) => e.id), ['a']);
      expect(c.canUndo, isFalse);
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
      c.currentStyle = const SketchStyle(strokeColor: Color(0xFFFF0000));
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
        initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b'),
          _rect(id: 'c'),
        ],
      );
      c.selectMany({'a', 'b'});
      expect(c.canUndo, isFalse);

      final changed = c.applyStyleToSelected(
        (s) => s.copyWith(strokeColor: red),
      );

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
      expect(
        c.elements.single.style.strokeWidth,
        const SketchStyle().strokeWidth,
      );
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

  group('replaceAll', () {
    test('prunes the selection of elements it removed', () {
      // An MCP `flowcraft_draw` with mode "replace" while something is
      // selected: the properties panel thought there was a selection, and
      // Delete reported "2 removed", pushed an undo entry and bumped
      // `paintGen` (an autosave write) while removing nothing.
      final c = SketchController()
        ..add(_rect(id: 'x'))
        ..add(_rect(id: 'y'));
      c.selectMany({'x', 'y'});

      c.replaceAll([_rect(id: 'z')]);

      expect(c.hasSelection, isFalse);
      expect(c.selectedIds, isEmpty);
      expect(c.isSelected('x'), isFalse);
      final gen = c.paintGen;
      expect(c.removeSelected(), 0);
      expect(c.paintGen, gen);
      expect(c.elements.single.id, 'z');
    });

    test('keeps a selected element that survives by id', () {
      final c = SketchController()
        ..add(_rect(id: 'x'))
        ..add(_rect(id: 'y'));
      c.selectMany({'x', 'y'});

      c.replaceAll([_rect(id: 'y', rect: const Rect.fromLTWH(5, 5, 5, 5))]);

      expect(c.selectedIds, {'y'});
    });

    test('abandons a text edit whose element vanished', () {
      final c = SketchController()..add(_rect(id: 'x'));
      c.beginTextEdit(elementId: 'x');

      c.replaceAll([_rect(id: 'z')]);

      expect(c.editingElementId, isNull);
      expect(c.editingCanvasPosition, isNull);
    });

    test('keeps a pending new-text edit — it references no element', () {
      final c = SketchController()..add(_rect(id: 'x'));
      c.beginTextEdit(canvasPosition: const Offset(3, 4));

      c.replaceAll([_rect(id: 'z')]);

      expect(c.editingCanvasPosition, const Offset(3, 4));
    });
  });

  group('select', () {
    test('selecting an unknown id clears the selection consistently', () {
      // The clear happened before the id was validated, and the early
      // return skipped the cache invalidation — so `selectedIds` kept
      // answering {x} while `isSelected`/`hasSelection` said nothing was.
      final c = SketchController()..add(_rect(id: 'x'));
      c.select('x');
      expect(c.selectedIds, {'x'});
      var notified = 0;
      c.addListener(() => notified++);

      c.select('does-not-exist');

      expect(c.isSelected('x'), isFalse);
      expect(c.hasSelection, isFalse);
      expect(c.selectedIds, isEmpty);
      expect(notified, 1);
    });

    test('an unknown id with clearExisting false changes nothing', () {
      final c = SketchController()..add(_rect(id: 'x'));
      c.select('x');
      var notified = 0;
      c.addListener(() => notified++);

      c.select('does-not-exist', clearExisting: false);

      expect(c.selectedIds, {'x'});
      expect(notified, 0);
    });
  });

  group('undo during a drag session', () {
    test('does not leave a stale snapshot', () {
      final c = SketchController(initialElements: [_rect(id: 'a')]);
      c.select('a');
      c.add(_rect(id: 'b'));

      // Ctrl+Z with the pointer still down, then the pointer moves.
      c.beginDragSession();
      c.undo();
      expect(c.elements.map((e) => e.id), ['a']);
      c.translateSelected(const Offset(5, 0));
      c.endDragSession();

      // The drag got its own entry, taken *after* the undo — so undoing it
      // lands on the post-undo scene, never on the pre-undo one.
      c.undo();
      expect(c.elements.map((e) => e.id), ['a']);
      expect(c.elements.single.bounds, const Rect.fromLTWH(0, 0, 10, 10));
      expect(c.canRedo, isTrue);
    });

    test('an MCP draw landing mid-drag survives the first undo after it', () {
      final c = SketchController(initialElements: [_rect(id: 'a')]);
      c.select('a');

      c.beginDragSession();
      c.addAll([_rect(id: 'agent')]); // flowcraft_draw, pointer still down
      c.translateSelected(const Offset(5, 0));
      c.endDragSession();

      c.undo(); // the drag
      expect(c.elements.map((e) => e.id), ['a', 'agent']);
      expect(c.elements.first.bounds, const Rect.fromLTWH(0, 0, 10, 10));
      c.undo(); // the agent's draw
      expect(c.elements.map((e) => e.id), ['a']);
    });
  });

  group('pasteElements', () {
    test('mints fresh ids, selects the copies, one history entry', () {
      final c = SketchController()..add(_rect(id: 'a'));

      final added = c.pasteElements([
        _rect(id: 'a'),
        _rect(id: 'b'),
      ], offset: Offset.zero);

      expect(added, 2);
      expect(c.elements, hasLength(3));
      expect(c.elements.map((e) => e.id).toSet(), hasLength(3));
      expect(c.selectedIds, hasLength(2));
      c.undo();
      expect(c.elements.map((e) => e.id), ['a']);
    });

    test('an empty list is a no-op with no history entry', () {
      final c = SketchController()..add(_rect(id: 'a'));
      final gen = c.paintGen;
      expect(c.pasteElements(const []), 0);
      expect(c.paintGen, gen);
    });
  });

  group('SketchController.updateLinear', () {
    SketchLine line() => SketchLine.create(
      id: 'l',
      start: Offset.zero,
      end: const Offset(10, 0),
    );

    test('moves one endpoint and leaves the other alone', () {
      final c = SketchController(initialElements: [line()]);
      c.updateLinear('l', end: const Offset(50, 20));

      final updated = c.elements.single as SketchLine;
      expect(updated.start, Offset.zero);
      expect(updated.end, const Offset(50, 20));
    });

    test('moves an arrow, and does nothing to a non-linear element', () {
      final c = SketchController(
        initialElements: [
          SketchArrow.create(
            id: 'a',
            start: Offset.zero,
            end: const Offset(5, 5),
          ),
          _rect(id: 'r'),
        ],
      );

      c.updateLinear('a', start: const Offset(1, 1));
      expect((c.elements.first as SketchArrow).start, const Offset(1, 1));

      final gen = c.paintGen;
      c.updateLinear('r', start: const Offset(9, 9));
      expect(c.paintGen, gen);
      expect(c.elements[1].bounds, const Rect.fromLTWH(0, 0, 10, 10));
    });

    test('an endpoint drag collapses into exactly one entry', () {
      final c = SketchController(initialElements: [line()]);

      c.beginDragSession();
      for (final dx in <double>[20, 30, 40]) {
        c.updateLinear('l', end: Offset(dx, 0));
      }
      c.endDragSession();

      expect((c.elements.single as SketchLine).end, const Offset(40, 0));
      c.undo();
      expect((c.elements.single as SketchLine).end, const Offset(10, 0));
      expect(c.canUndo, isFalse);
    });

    test('a session whose calls move nothing leaves history untouched', () {
      final c = SketchController(initialElements: [line()]);

      c.beginDragSession();
      // A pointer parked on the handle: same endpoint, over and over.
      c.updateLinear('l', end: const Offset(10, 0));
      c.updateLinear('l');
      c.endDragSession();

      expect(c.canUndo, isFalse);
    });
  });

  group('SketchController.duplicateSelected', () {
    test('copies get fresh ids, the offset, and the selection', () {
      final c = SketchController(
        initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b', rect: const Rect.fromLTWH(50, 0, 10, 10)),
        ],
      );
      c.selectMany({'a', 'b'});

      expect(c.duplicateSelected(), 2);

      expect(c.elements.length, 4);
      expect(c.elements.take(2).map((e) => e.id), ['a', 'b']);

      final copies = c.elements.skip(2).toList();
      // Fresh ids: two elements sharing one would give selection,
      // hit-testing and MCP addressing a single handle for both.
      expect(copies.map((e) => e.id).toSet().intersection({'a', 'b'}), isEmpty);
      expect(copies.map((e) => e.id).toSet().length, 2);
      expect(copies[0].bounds, const Rect.fromLTWH(16, 16, 10, 10));
      expect(copies[1].bounds, const Rect.fromLTWH(66, 16, 10, 10));
      expect(c.selectedIds, copies.map((e) => e.id).toSet());
    });

    test('is exactly one undo entry', () {
      final c = SketchController(initialElements: [_rect(id: 'a')]);
      c.select('a');

      c.duplicateSelected();
      expect(c.elements.length, 2);

      c.undo();
      expect(c.elements.map((e) => e.id), ['a']);
      expect(c.canUndo, isFalse);
    });

    test('duplicating a group makes a second, independent group', () {
      final c = SketchController(
        initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b'),
        ],
      );
      c.selectMany({'a', 'b'});
      c.groupSelected();
      final original = c.elements.first.groupId;

      c.duplicateSelected();

      final copies = c.elements.skip(2).toList();
      expect(copies[0].groupId, isNotNull);
      expect(copies[0].groupId, copies[1].groupId);
      // Reusing the source group id would fuse copy to original, so
      // dragging one would drag the other.
      expect(copies[0].groupId, isNot(original));
      expect(c.elements.first.groupId, original);
    });

    test('is a no-op without a selection', () {
      final c = SketchController(initialElements: [_rect(id: 'a')]);
      final gen = c.paintGen;

      expect(c.duplicateSelected(), 0);
      expect(c.elements.length, 1);
      expect(c.paintGen, gen);
      expect(c.canUndo, isFalse);
    });
  });

  group('SketchController copy / paste', () {
    test('a copied selection pastes back with fresh ids', () {
      final c = SketchController(
        initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b'),
        ],
      );
      c.select('a');

      final json = c.copySelectionToJson()!;
      expect(c.pasteFromJson(json), 1);

      expect(c.elements.map((e) => e.id).take(2), ['a', 'b']);
      expect(c.elements.length, 3);
      expect(c.elements.last.id, isNot('a'));
      expect(c.selectedIds, {c.elements.last.id});
    });

    test('copySelectionToJson is null without a selection', () {
      final c = SketchController(initialElements: [_rect(id: 'a')]);
      expect(c.copySelectionToJson(), isNull);
    });

    test('pastes a scene copied in another window', () {
      // Going through SketchSerializer is what makes this work: the
      // clipboard carries the same format a saved project holds.
      final json = SketchSerializer.serialize([
        _rect(id: 'a'),
        _rect(id: 'b', rect: const Rect.fromLTWH(50, 0, 10, 10)),
      ]);
      final c = SketchController();

      expect(c.pasteFromJson(json, offset: Offset.zero), 2);
      expect(c.elements.map((e) => e.bounds), [
        const Rect.fromLTWH(0, 0, 10, 10),
        const Rect.fromLTWH(50, 0, 10, 10),
      ]);
    });

    test('never throws on hostile clipboard text', () {
      final c = SketchController();

      // Whatever the system clipboard happened to hold. None of it may
      // reach the UI as an exception.
      for (final hostile in <String>[
        '',
        'not json at all',
        '[]',
        'null',
        '{}',
        '{"version": 1}',
        '{"version": 1, "elements": "nope"}',
        '{"version": 999, "elements": []}',
        '{"version": 1, "elements": [null]}',
      ]) {
        expect(c.pasteFromJson(hostile), 0, reason: 'input: "$hostile"');
      }

      expect(c.elements, isEmpty);
      expect(c.canUndo, isFalse);
    });

    test('skips an unparseable element and pastes the rest', () {
      final c = SketchController();
      final json = jsonEncode({
        'version': SketchSerializer.schemaVersion,
        'elements': [
          _rect(id: 'a').toJson(),
          {'type': 'wormhole', 'id': 'x'},
        ],
      });

      expect(c.pasteFromJson(json), 1);
      // A lossy *paste* overwrites nothing, so it is not the data-loss case
      // sceneIsPartial exists to guard.
      expect(c.sceneIsPartial, isFalse);
    });

    test('is exactly one undo entry', () {
      final c = SketchController(initialElements: [_rect(id: 'a')]);
      c.select('a');
      final json = c.copySelectionToJson()!;

      c.pasteFromJson(json);
      expect(c.elements.length, 2);

      c.undo();
      expect(c.elements.map((e) => e.id), ['a']);
      expect(c.canUndo, isFalse);
    });
  });

  group('SketchController z-order', () {
    SketchController scene() => SketchController(
      initialElements: [
        _rect(id: 'a'),
        _rect(id: 'b'),
        _rect(id: 'c'),
        _rect(id: 'd'),
      ],
    );

    List<String> order(SketchController c) =>
        c.elements.map((e) => e.id).toList();

    test('bringToFront keeps the selection in its own order', () {
      final c = scene();
      c.selectMany({'a', 'c'});
      c.bringToFront();
      expect(order(c), ['b', 'd', 'a', 'c']);
    });

    test('sendToBack keeps the selection in its own order', () {
      final c = scene();
      c.selectMany({'b', 'd'});
      c.sendToBack();
      expect(order(c), ['b', 'd', 'a', 'c']);
    });

    test('bringForward moves each run one step, independently', () {
      final c = scene();
      // Non-contiguous: 'a' has room to rise, 'd' is already on top and
      // must simply stay there rather than dragging 'a' up beside it.
      c.selectMany({'a', 'd'});
      c.bringForward();
      expect(order(c), ['b', 'a', 'c', 'd']);
    });

    test('sendBackward moves each run one step, independently', () {
      final c = scene();
      c.selectMany({'a', 'd'});
      c.sendBackward();
      expect(order(c), ['a', 'b', 'd', 'c']);
    });

    test('a contiguous run keeps its internal order', () {
      final c = scene();
      c.selectMany({'a', 'b'});
      c.bringForward();
      expect(order(c), ['c', 'a', 'b', 'd']);
    });

    test('a selection already at the front records nothing', () {
      final c = scene();
      c.selectMany({'c', 'd'});

      c.bringToFront();
      c.bringForward();

      expect(order(c), ['a', 'b', 'c', 'd']);
      expect(c.canUndo, isFalse);
    });

    test('is exactly one undo entry', () {
      final c = scene();
      c.select('a');

      c.bringToFront();
      expect(order(c), ['b', 'c', 'd', 'a']);

      c.undo();
      expect(order(c), ['a', 'b', 'c', 'd']);
      expect(c.canUndo, isFalse);
    });
  });

  group('SketchController grouping', () {
    test('groupSelected puts the selection in one new group', () {
      final c = SketchController(
        initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b'),
          _rect(id: 'c'),
        ],
      );
      c.selectMany({'a', 'b'});

      c.groupSelected();

      final group = c.elements[0].groupId;
      expect(group, isNotNull);
      expect(c.elements[1].groupId, group);
      expect(c.elements[2].groupId, isNull);

      c.undo();
      expect(c.elements.map((e) => e.groupId), everyElement(isNull));
      expect(c.canUndo, isFalse);
    });

    test('flattens a selection spanning two groups into one', () {
      final c = SketchController(
        initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b'),
          _rect(id: 'c'),
          _rect(id: 'd'),
        ],
      );
      c.selectMany({'a', 'b'});
      c.groupSelected();
      final first = c.elements[0].groupId;
      c.selectMany({'c', 'd'});
      c.groupSelected();
      final second = c.elements[2].groupId;

      c.selectMany({'a', 'b', 'c', 'd'});
      c.groupSelected();

      // Flat, not nested: groupId has no parent to nest into.
      final merged = c.elements.map((e) => e.groupId).toSet();
      expect(merged.length, 1);
      expect(merged.single, isNot(first));
      expect(merged.single, isNot(second));
    });

    test('re-grouping an intact group records nothing', () {
      final c = SketchController(
        initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b'),
        ],
      );
      c.selectMany({'a', 'b'});
      c.groupSelected();
      final group = c.elements.first.groupId;

      c.groupSelected();

      expect(c.elements.first.groupId, group);
      c.undo();
      expect(c.elements.map((e) => e.groupId), everyElement(isNull));
      expect(c.canUndo, isFalse);
    });

    test('a single element cannot be grouped', () {
      final c = SketchController(initialElements: [_rect(id: 'a')]);
      c.select('a');

      c.groupSelected();

      expect(c.elements.single.groupId, isNull);
      expect(c.canUndo, isFalse);
    });

    test('ungroupSelected clears the group in one entry', () {
      final c = SketchController(
        initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b'),
        ],
      );
      c.selectMany({'a', 'b'});
      c.groupSelected();
      final group = c.elements.first.groupId;

      c.ungroupSelected();
      expect(c.elements.map((e) => e.groupId), everyElement(isNull));

      c.undo();
      expect(c.elements.map((e) => e.groupId), everyElement(group));
    });

    test('ungroupSelected records nothing when nothing is grouped', () {
      final c = SketchController(
        initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b'),
        ],
      );
      c.selectMany({'a', 'b'});

      c.ungroupSelected();

      expect(c.canUndo, isFalse);
    });

    test('expandToGroups pulls in the rest of a group', () {
      final c = SketchController(
        initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b'),
          _rect(id: 'c'),
        ],
      );
      c.selectMany({'a', 'b'});
      c.groupSelected();

      expect(c.expandToGroups({'a'}), {'a', 'b'});
      expect(c.expandToGroups({'c'}), {'c'});
      // Validating ids is selectMany's job, not this one's.
      expect(c.expandToGroups({'gone'}), {'gone'});
    });

    test('expandToGroups sees grouping done after its first call', () {
      final c = SketchController(
        initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b'),
        ],
      );
      // Primes the cached group index; a stale one would keep selecting
      // yesterday's groups on every click.
      expect(c.expandToGroups({'a'}), {'a'});

      c.selectMany({'a', 'b'});
      c.groupSelected();
      expect(c.expandToGroups({'a'}), {'a', 'b'});

      c.ungroupSelected();
      expect(c.expandToGroups({'a'}), {'a'});
    });
  });

  group('SketchController partial scenes', () {
    test('a scene loaded with drops is marked partial', () {
      final c = SketchController();

      c.loadScene([_rect(id: 'a')], droppedOnLoad: 2);

      expect(c.droppedOnLoad, 2);
      // Autosave must not write over the file while this is true, or the
      // two unreadable elements are gone for good.
      expect(c.sceneIsPartial, isTrue);
    });

    test('a clean load clears the mark', () {
      final c = SketchController();
      c.loadScene([_rect(id: 'a')], droppedOnLoad: 2);

      c.loadScene([_rect(id: 'b')]);

      expect(c.sceneIsPartial, isFalse);
      expect(c.droppedOnLoad, 0);
    });

    test('acknowledging clears it once and notifies', () {
      final c = SketchController();
      c.loadScene([_rect(id: 'a')], droppedOnLoad: 1);
      var notified = 0;
      c.addListener(() => notified++);

      c.acknowledgePartialScene();
      expect(c.sceneIsPartial, isFalse);
      expect(notified, 1);

      c.acknowledgePartialScene();
      expect(notified, 1);
    });
  });

  group('sticky notes collapse when the edit ends', () {
    const rect = Rect.fromLTWH(20, 30, 200, 90);

    SketchController withNote({String? text}) {
      final c = SketchController();
      c.add(SketchSticky.create(id: 'note', rect: rect, text: text));
      return c;
    }

    SketchSticky noteIn(SketchController c) =>
        c.elements.single as SketchSticky;

    test('committing text collapses the note to its badge', () {
      final c = withNote();
      c.beginTextEdit(elementId: 'note');
      c.commitTextEdit('buy milk');

      final note = noteIn(c);
      expect(note.text, 'buy milk');
      expect(note.collapsed, isTrue);
      // The bubble's geometry survives underneath, so reopening restores the
      // size and position the user had.
      expect(note.rect, rect);
    });

    test('committing text that overflows grows the bubble first', () {
      // A messenger bubble takes the height of its message; the grow has
      // to happen *before* the collapse, because a badge has no bubble to
      // measure.
      final c = withNote();
      c.beginTextEdit(elementId: 'note');
      c.commitTextEdit(
        'A note long enough that it has to wrap onto several lines, which '
        'the default height was never meant to hold, and then some more.',
      );
      final note = noteIn(c);
      expect(note.collapsed, isTrue);
      expect(note.rect.height, greaterThan(rect.height));
      expect(note.rect.width, rect.width);
    });

    test('collapse, growth and text land in one undo entry', () {
      final c = withNote();
      c.beginTextEdit(elementId: 'note');
      c.commitTextEdit('buy milk');
      expect(noteIn(c).collapsed, isTrue);
      expect(noteIn(c).text, 'buy milk');

      // All must come back together. Collapsing through a second mutation
      // would leave the user undoing the collapse first and finding a bubble
      // with text they had already undone away.
      c.undo();
      expect(noteIn(c).collapsed, isFalse);
      expect(noteIn(c).text, isNull);
      expect(noteIn(c).rect, rect);
      expect(c.canUndo, isTrue, reason: 'only the add remains');
      c.undo();
      expect(c.elements, isEmpty);
    });

    test('cancelling leaves the note exactly as it found it', () {
      // Commit means "done with this note"; cancel means "forget I started".
      final c = withNote(text: 'already here');
      c.beginTextEdit(elementId: 'note');
      c.cancelTextEdit();

      expect(noteIn(c).collapsed, isFalse);
      expect(noteIn(c).text, 'already here');
    });

    test('an emptied note collapses like any other, and is not deleted', () {
      // Nothing is exempt from "click away, it closes": a note left open
      // because it was blank is a note that looks stuck. And it is not
      // removed the way an empty SketchText is — it still has its colour,
      // position and size.
      final c = withNote(text: 'was here');
      c.beginTextEdit(elementId: 'note');
      c.commitTextEdit('   ');

      expect(c.elements, hasLength(1));
      expect(noteIn(c).text, isNull);
      expect(noteIn(c).collapsed, isTrue);
    });

    test('a shape label is untouched by any of this', () {
      final c = SketchController();
      c.add(_rect(id: 'box'));
      c.beginTextEdit(elementId: 'box');
      c.commitTextEdit('label');
      expect((c.elements.single as SketchRectangle).text, 'label');
    });
  });

  group('SketchController.setStickyCollapsed', () {
    const rect = Rect.fromLTWH(0, 0, 200, 90);

    SketchController withCollapsedNote() {
      final c = SketchController();
      c.add(
        SketchSticky.create(
          id: 'note',
          rect: rect,
          text: 'hi',
          collapsed: true,
        ),
      );
      return c;
    }

    test('expanding restores the original geometry, not a default', () {
      final c = withCollapsedNote();
      c.setStickyCollapsed('note', false);
      final note = c.elements.single as SketchSticky;
      expect(note.collapsed, isFalse);
      expect(note.rect, rect);
      expect(note.bounds, rect);
    });

    test('is view state: it repaints but is not undoable', () {
      // Open-or-closed is a side-effect of clicks whose purpose was
      // something else; an undo entry per toggle would make Ctrl+Z reopen
      // a note instead of undoing the thing the user actually did. It does
      // bump paintGen, because it is persisted — autosave has to see it.
      final c = withCollapsedNote();
      final gen = c.paintGen;
      c.setStickyCollapsed('note', false);
      expect(c.paintGen, greaterThan(gen));

      c.undo();
      // The only entry on the stack is the add, so one undo empties the
      // canvas rather than re-collapsing the note.
      expect(c.elements, isEmpty);
    });

    test('is a no-op when the note is already in that state', () {
      final c = withCollapsedNote();
      final gen = c.paintGen;
      c.setStickyCollapsed('note', true);
      expect(c.paintGen, gen);
    });

    test('ignores ids that are missing or not notes', () {
      final c = SketchController();
      c.add(_rect(id: 'box'));
      final gen = c.paintGen;
      c.setStickyCollapsed('box', true);
      c.setStickyCollapsed('nobody', true);
      expect(c.paintGen, gen);
      expect(c.elements.single, isA<SketchRectangle>());
    });
  });

  group('SketchController.collapseExpandedStickies', () {
    const rect = Rect.fromLTWH(0, 0, 200, 90);

    SketchController board() {
      final c = SketchController();
      c.addAll([
        SketchSticky.create(id: 'a', rect: rect, text: 'a'),
        SketchSticky.create(
          id: 'b',
          rect: rect.shift(const Offset(300, 0)),
          text: 'b',
        ),
        SketchSticky.create(
          id: 'c',
          rect: rect.shift(const Offset(600, 0)),
          text: 'c',
          collapsed: true,
        ),
        _rect(id: 'box'),
      ]);
      return c;
    }

    bool collapsed(SketchController c, String id) =>
        (c.elements.firstWhere((e) => e.id == id) as SketchSticky).collapsed;

    test('closes every open note but the one kept', () {
      final c = board();
      expect(c.collapseExpandedStickies(except: 'b'), 1);
      expect(collapsed(c, 'a'), isTrue);
      expect(collapsed(c, 'b'), isFalse);
      expect(collapsed(c, 'c'), isTrue);
    });

    test('with nothing kept, closes them all', () {
      final c = board();
      expect(c.collapseExpandedStickies(), 2);
      expect(collapsed(c, 'a'), isTrue);
      expect(collapsed(c, 'b'), isTrue);
    });

    test('reports zero and does not repaint when nothing was open', () {
      final c = board();
      c.collapseExpandedStickies();
      final gen = c.paintGen;
      expect(c.collapseExpandedStickies(), 0);
      expect(c.paintGen, gen);
    });

    test('leaves no undo entry', () {
      final c = board();
      c.collapseExpandedStickies();
      c.undo();
      // The one entry is the addAll; undoing it empties the board rather
      // than reopening the notes.
      expect(c.elements, isEmpty);
    });

    test('keeps the rect underneath, so reopening restores it', () {
      final c = board();
      c.collapseExpandedStickies();
      c.setStickyCollapsed('a', false);
      expect((c.elements.first as SketchSticky).rect, rect);
    });
  });

  group('arrow binding', () {
    SketchRectangle shape(String id, double x) =>
        _rect(id: id, rect: Rect.fromLTWH(x, 0, 100, 100));

    // a at x 0..100, b at x 300..400, arrow bound a -> b.
    SketchController bound() {
      final arrow =
          SketchArrow.create(
            id: 'arr',
            start: const Offset(100, 50),
            end: const Offset(300, 50),
          ).copyWith(
            startBinding: const SketchBinding(elementId: 'a'),
            endBinding: const SketchBinding(elementId: 'b'),
          );
      return SketchController()
        ..addAll([shape('a', 0), shape('b', 300), arrow]);
    }

    SketchArrow arr(SketchController c) =>
        c.elements.firstWhere((e) => e.id == 'arr') as SketchArrow;

    test('translateSelected on the shape re-routes the arrow', () {
      final c = bound()..select('b');
      c.translateSelected(const Offset(0, 200));
      expect(arr(c).end.dy, greaterThan(100));
      expect(arr(c).endBinding, isNotNull);
    });

    test('resizeElement on the shape re-routes the arrow', () {
      final c = bound();
      c.resizeElement('b', const Rect.fromLTWH(500, 0, 100, 100));
      expect(arr(c).end.dx, closeTo(500, 0.01));
    });

    test('updateAll on the shape re-routes the arrow', () {
      final c = bound();
      c.updateAll([shape('b', 700)]);
      expect(arr(c).end.dx, closeTo(700, 0.01));
    });

    test('removing the shape clears the binding and the arrow stays', () {
      final c = bound();
      final before = arr(c).end;
      c.remove('b');
      expect(arr(c).endBinding, isNull);
      expect(arr(c).startBinding, isNotNull);
      expect(arr(c).end, before);
    });

    test('translating the arrow alone unbinds, with its shape keeps', () {
      final alone = bound()..select('arr');
      alone.translateSelected(const Offset(0, 500));
      expect(arr(alone).startBinding, isNull);
      expect(arr(alone).endBinding, isNull);
      expect(arr(alone).start.dy, 550);

      final together = bound()..selectMany(['arr', 'a', 'b']);
      together.translateSelected(const Offset(0, 500));
      expect(arr(together).startBinding, isNotNull);
      expect(arr(together).endBinding, isNotNull);
      expect(arr(together).start.dy, closeTo(550, 0.01));
    });

    test('updateLinear clears only the moved end', () {
      final c = bound();
      c.updateLinear('arr', end: const Offset(900, 900));
      expect(arr(c).endBinding, isNull);
      expect(arr(c).startBinding, isNotNull);
      expect(arr(c).end, const Offset(900, 900));
    });

    test('setArrowBindings is one undo entry restoring endpoints too', () {
      final c = SketchController()
        ..addAll([
          shape('a', 0),
          SketchArrow.create(
            id: 'arr',
            start: const Offset(50, 50),
            end: const Offset(400, 50),
          ),
        ]);
      final gen = c.paintGen;
      c.setArrowBindings(
        'arr',
        start: const SketchBinding(elementId: 'a'),
        end: null,
      );
      expect(c.paintGen, gen + 1);
      expect(arr(c).start.dx, closeTo(100, 0.01));
      c.undo();
      expect(arr(c).start, const Offset(50, 50));
      expect(arr(c).startBinding, isNull);
      c.redo();
      expect(arr(c).start.dx, closeTo(100, 0.01));
      expect(arr(c).startBinding, isNotNull);
    });

    test('setArrowBindings is a no-op when unchanged', () {
      final c = bound();
      final gen = c.paintGen;
      c.setArrowBindings(
        'arr',
        start: const SketchBinding(elementId: 'a'),
        end: const SketchBinding(elementId: 'b'),
      );
      expect(c.paintGen, gen);
    });

    test('setArrowBindings joins an open drag session', () {
      final c = SketchController()
        ..addAll([
          shape('a', 0),
          SketchArrow.create(
            id: 'arr',
            start: const Offset(50, 50),
            end: const Offset(400, 50),
          ),
        ]);
      c.beginDragSession();
      c.updateLinear('arr', start: const Offset(60, 60));
      c.setArrowBindings(
        'arr',
        start: const SketchBinding(elementId: 'a'),
        end: null,
      );
      c.endDragSession();
      c.undo(); // one entry for drag + bind: back to the pre-drag arrow
      expect(arr(c).start, const Offset(50, 50));
      expect(arr(c).startBinding, isNull);
    });

    test('undo and redo keep endpoints consistent with the shape', () {
      final c = bound()..select('b');
      c.beginDragSession();
      c.translateSelected(const Offset(0, 200));
      c.endDragSession();
      final moved = arr(c).end;
      c.undo();
      expect(arr(c).end.dx, closeTo(300, 0.01));
      expect(arr(c).end.dy, closeTo(50, 0.01));
      c.redo();
      expect(arr(c).end, moved);
    });

    test('loadScene clears a dangling binding without history', () {
      final c = SketchController();
      c.loadScene([
        SketchArrow.create(
          id: 'arr',
          start: Offset.zero,
          end: const Offset(10, 10),
        ).copyWith(endBinding: const SketchBinding(elementId: 'nope')),
      ]);
      expect(arr(c).endBinding, isNull);
      expect(c.canUndo, isFalse);
    });

    test('each mutation bumps paintGen once', () {
      final c = bound()..select('b');
      final gen = c.paintGen;
      c.translateSelected(const Offset(0, 50));
      expect(c.paintGen, gen + 1);
    });
  });

  group('align / distribute', () {
    SketchController scene() => SketchController()
      ..addAll([
        _rect(id: 'a', rect: const Rect.fromLTWH(0, 0, 10, 10)),
        _rect(id: 'b', rect: const Rect.fromLTWH(50, 30, 20, 20)),
        _rect(id: 'c', rect: const Rect.fromLTWH(200, 100, 40, 10)),
      ])
      ..selectMany(['a', 'b', 'c']);

    Rect at(SketchController c, String id) =>
        (c.elements.firstWhere((e) => e.id == id) as SketchRectangle).rect;

    test('each edge moves units to the union edge as one undo entry', () {
      final expected = <AlignEdge, bool Function(Rect)>{
        AlignEdge.left: (r) => r.left == 0,
        AlignEdge.right: (r) => r.right == 240,
        AlignEdge.top: (r) => r.top == 0,
        AlignEdge.bottom: (r) => r.bottom == 110,
        AlignEdge.centerX: (r) => r.center.dx == 120,
        AlignEdge.centerY: (r) => r.center.dy == 55,
      };
      for (final entry in expected.entries) {
        final c = scene();
        final gen = c.paintGen;
        expect(
          c.alignSelected(entry.key),
          greaterThan(0),
          reason: '${entry.key}',
        );
        expect(c.paintGen, gen + 1);
        for (final id in ['a', 'b', 'c']) {
          expect(entry.value(at(c, id)), isTrue, reason: '${entry.key} $id');
        }
        c.undo();
        expect(at(c, 'a'), const Rect.fromLTWH(0, 0, 10, 10));
        expect(at(c, 'c'), const Rect.fromLTWH(200, 100, 40, 10));
      }
    });

    test('a group moves as a unit', () {
      final c = scene();
      c.selectMany(['a', 'b']);
      c.groupSelected();
      c.selectMany(['a', 'c']); // expands to the group + c
      c.alignSelected(AlignEdge.left);
      // group (a,b) bounds left 0 already; c moves to 0, b keeps its offset.
      expect(at(c, 'c').left, 0);
      expect(at(c, 'b').left, 50);
    });

    test('fewer than two units or already aligned is a no-op', () {
      final one = scene()..select('a');
      var gen = one.paintGen;
      expect(one.alignSelected(AlignEdge.left), 0);
      expect(one.paintGen, gen);

      final c = scene();
      c.alignSelected(AlignEdge.left);
      gen = c.paintGen;
      final canUndo = c.canUndo;
      expect(c.alignSelected(AlignEdge.left), 0);
      expect(c.paintGen, gen);
      expect(c.canUndo, canUndo);
    });

    test('distribute gives equal gaps with first and last fixed', () {
      final c = scene();
      expect(c.distributeSelected(Axis.horizontal), 1);
      expect(at(c, 'a').left, 0);
      expect(at(c, 'c').right, 240);
      final gap1 = at(c, 'b').left - at(c, 'a').right;
      final gap2 = at(c, 'c').left - at(c, 'b').right;
      expect(gap1, closeTo(gap2, 1e-9));
      c.undo();
      expect(at(c, 'b').left, 50);
    });

    test('distribute with fewer than three units is a no-op', () {
      final c = scene()..selectMany(['a', 'b']);
      final gen = c.paintGen;
      expect(c.distributeSelected(Axis.vertical), 0);
      expect(c.paintGen, gen);
    });

    test('bound arrows are not units but follow their shapes', () {
      final arrow =
          SketchArrow.create(
            id: 'arr',
            start: const Offset(10, 5),
            end: const Offset(200, 105),
          ).copyWith(
            startBinding: const SketchBinding(elementId: 'a'),
            endBinding: const SketchBinding(elementId: 'c'),
          );
      final c = scene()..add(arrow);
      c.selectMany(['a', 'c', 'arr']);
      expect(c.alignSelected(AlignEdge.top), 1); // only c moves
      final a = at(c, 'a');
      final cc = at(c, 'c');
      final arr = c.elements.last as SketchArrow;
      expect(arr.startBinding, isNotNull);
      expect(a.inflate(0.5).contains(arr.start), isTrue);
      expect(cc.inflate(0.5).contains(arr.end), isTrue);
    });
  });

  group('requestFrame', () {
    const r = Rect.fromLTWH(0, 0, 10, 10);

    test('bumps frameRequestGen and notifies but not paintGen', () {
      final c = SketchController();
      var notified = 0;
      c.addListener(() => notified++);
      final gen = c.paintGen;
      c.requestFrame(r);
      expect(c.frameRequestGen, 1);
      expect(c.frameRequest, (rect: r, onlyIfHidden: false));
      expect(notified, 1);
      expect(c.paintGen, gen);
    });

    test('the same rect twice bumps twice', () {
      final c = SketchController()
        ..requestFrame(r)
        ..requestFrame(r);
      expect(c.frameRequestGen, 2);
    });

    test('a non-finite rect is ignored', () {
      final c = SketchController()
        ..requestFrame(const Rect.fromLTWH(double.nan, 0, 1, 1))
        ..requestFrame(const Rect.fromLTWH(0, 0, double.infinity, 1));
      expect(c.frameRequestGen, 0);
      expect(c.frameRequest, isNull);
    });

    test('onlyIfHidden is dropped during a drag session', () {
      final c = SketchController()..beginDragSession();
      c.requestFrame(r, onlyIfHidden: true);
      expect(c.frameRequestGen, 0);
      c.requestFrame(r);
      expect(c.frameRequestGen, 1);
    });
  });

  group('phase 2 controller', () {
    test('dragging a frame moves its members only, one undo entry', () {
      final c = SketchController();
      final frame = SketchFrame.create(
        id: 'f',
        rect: const Rect.fromLTWH(0, 0, 100, 100),
      );
      final inside = _rect(id: 'in', rect: const Rect.fromLTWH(10, 10, 20, 20));
      final outside = _rect(
        id: 'out',
        rect: const Rect.fromLTWH(200, 0, 20, 20),
      );
      c.addAll([frame, inside, outside]);
      c.select('f');
      c.beginDragSession();
      c.translateSelected(const Offset(5, 0));
      // Frame now overlaps nothing new, but passes over `out` mid-drag.
      c.translateSelected(const Offset(150, 0));
      c.endDragSession();
      Rect r(String id) => c.elements.firstWhere((e) => e.id == id).bounds;
      expect(r('f').left, 155);
      expect(r('in').left, 165);
      expect(r('out').left, 200);
      c.undo();
      expect(r('f').left, 0);
      expect(r('in').left, 10);
    });

    test('resizing a frame leaves members', () {
      final c = SketchController();
      c.addAll([
        SketchFrame.create(id: 'f', rect: const Rect.fromLTWH(0, 0, 100, 100)),
        _rect(id: 'in', rect: const Rect.fromLTWH(10, 10, 20, 20)),
      ]);
      c.resizeElement('f', const Rect.fromLTWH(0, 0, 300, 300));
      expect(c.elements.firstWhere((e) => e.id == 'f').bounds.width, 300);
      expect(c.elements.firstWhere((e) => e.id == 'in').bounds.left, 10);
    });

    test('requestReveal bumps revealGen not paintGen', () {
      final c = SketchController();
      final paint = c.paintGen;
      c.requestReveal(['a', 'b']);
      expect(c.revealGen, 1);
      expect(c.revealRequest, ['a', 'b']);
      expect(c.paintGen, paint);
      expect(c.canUndo, isFalse);
    });
  });
}
