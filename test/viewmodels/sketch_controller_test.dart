import 'dart:convert';
import 'dart:ui';

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
      final c = SketchController(initialElements: [
        SketchArrow.create(
          id: 'a',
          start: Offset.zero,
          end: const Offset(5, 5),
        ),
        _rect(id: 'r'),
      ]);

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
      final c = SketchController(initialElements: [
        _rect(id: 'a'),
        _rect(id: 'b', rect: const Rect.fromLTWH(50, 0, 10, 10)),
      ]);
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
        initialElements: [_rect(id: 'a'), _rect(id: 'b')],
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
        initialElements: [_rect(id: 'a'), _rect(id: 'b')],
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
    SketchController scene() => SketchController(initialElements: [
          _rect(id: 'a'),
          _rect(id: 'b'),
          _rect(id: 'c'),
          _rect(id: 'd'),
        ]);

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
        initialElements: [_rect(id: 'a'), _rect(id: 'b'), _rect(id: 'c')],
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
      final c = SketchController(initialElements: [
        _rect(id: 'a'),
        _rect(id: 'b'),
        _rect(id: 'c'),
        _rect(id: 'd'),
      ]);
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
        initialElements: [_rect(id: 'a'), _rect(id: 'b')],
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
        initialElements: [_rect(id: 'a'), _rect(id: 'b')],
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
        initialElements: [_rect(id: 'a'), _rect(id: 'b')],
      );
      c.selectMany({'a', 'b'});

      c.ungroupSelected();

      expect(c.canUndo, isFalse);
    });

    test('expandToGroups pulls in the rest of a group', () {
      final c = SketchController(
        initialElements: [_rect(id: 'a'), _rect(id: 'b'), _rect(id: 'c')],
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
        initialElements: [_rect(id: 'a'), _rect(id: 'b')],
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
}
