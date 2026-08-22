import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Rect;
import 'dart:ui' show Offset;

import 'package:flowcraft/core/domain/sketch_hit_test.dart';
import 'package:flowcraft/core/serialization/sketch_serializer.dart';
import 'package:flowcraft/core/utils/id_generator.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/models/sketch_tool.dart';
import 'package:flowcraft/viewmodels/sketch_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Central state for the sketch (drawing) layer.
///
/// Holds the element list, current tool, current default style, and
/// selection. Fully self-contained — the whiteboard canvas only reads the
/// viewport through a provider, so the two layers stay independent.
class SketchController extends ChangeNotifier {
  SketchController({
    List<SketchElement>? initialElements,
    SketchTool currentTool = SketchTool.select,
    SketchStyle currentStyle = const SketchStyle(),
    int maxHistory = 50,
  })  : _elements = [...?initialElements],
        _currentTool = currentTool,
        _currentStyle = currentStyle,
        _history = SketchHistory(maxHistory: maxHistory);

  final List<SketchElement> _elements;
  final Set<String> _selectedIds = <String>{};
  final SketchHistory _history;

  SketchTool _currentTool;
  SketchStyle _currentStyle;

  int _paintGen = 0;

  String? _editingElementId;
  Offset? _editingCanvasPosition;

  int _droppedOnLoad = 0;

  List<SketchElement>? _cachedElements;
  Set<String>? _cachedSelectedIds;
  Map<String, List<String>>? _cachedGroups;

  // ── Getters ────────────────────────────────────────────────────────────

  List<SketchElement> get elements =>
      _cachedElements ??= List<SketchElement>.unmodifiable(_elements);

  Set<String> get selectedIds =>
      _cachedSelectedIds ??= Set<String>.unmodifiable(_selectedIds);

  SketchTool get currentTool => _currentTool;
  SketchStyle get currentStyle => _currentStyle;

  /// Monotonically increasing version bumped on every visual change.
  /// Use in `CustomPainter.shouldRepaint` for O(1) diffing.
  int get paintGen => _paintGen;

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  /// How many elements the open scene's file held that failed to decode, as
  /// reported to [loadScene]. `0` for a clean load.
  int get droppedOnLoad => _droppedOnLoad;

  /// Whether the canvas holds *less* than the file it came from.
  ///
  /// Autosave must not write while this is true: the reduced scene would
  /// overwrite the elements that failed to load and make a recoverable file
  /// permanently lossy. The user has to be told, and to accept the loss via
  /// [acknowledgePartialScene], before the file may be rewritten.
  bool get sceneIsPartial => _droppedOnLoad > 0;

  bool isSelected(String id) => _selectedIds.contains(id);
  bool get hasSelection => _selectedIds.isNotEmpty;

  /// Element currently in text-edit mode, or `null` when no edit is active.
  String? get editingElementId => _editingElementId;

  /// Canvas-space position used when the editor is creating a *new*
  /// [SketchText] element (no shape to anchor to yet).
  Offset? get editingCanvasPosition => _editingCanvasPosition;

  /// Topmost element under [point] in canvas-space, within [tolerance]
  /// pixels for stroke-only / linear shapes. Returns `null` if no hit.
  SketchElement? elementAt(Offset point, {double tolerance = 8.0}) =>
      SketchHitTest.topMost(_elements, point, tolerance);

  // ── Tool / style ───────────────────────────────────────────────────────

  set currentTool(SketchTool tool) {
    if (_currentTool == tool) return;
    _currentTool = tool;
    // Switching to a non-select tool deselects to avoid accidental moves.
    if (tool != SketchTool.select && _selectedIds.isNotEmpty) {
      _selectedIds.clear();
      _cachedSelectedIds = null;
    }
    notifyListeners();
  }

  set currentStyle(SketchStyle style) {
    if (_currentStyle == style) return;
    _currentStyle = style;
    notifyListeners();
  }

  // ── Mutations (history-tracked) ────────────────────────────────────────

  /// Adds an element to the top of the stack.
  void add(SketchElement element) {
    _pushHistory();
    _elements.add(element);
    _invalidateCache();
    _bumpPaint();
  }

  /// Adds many elements at once (single history entry).
  void addAll(Iterable<SketchElement> elements) {
    final list = elements.toList(growable: false);
    if (list.isEmpty) return;
    _pushHistory();
    _elements.addAll(list);
    _invalidateCache();
    _bumpPaint();
  }

  /// Replaces the element with matching id. No-op if absent.
  void update(SketchElement element) {
    final idx = _indexOf(element.id);
    if (idx < 0) return;
    _pushHistory();
    _elements[idx] = element;
    _invalidateCache();
    _bumpPaint();
  }

  /// Removes the element with [id]. No-op if absent.
  void remove(String id) {
    final idx = _indexOf(id);
    if (idx < 0) return;
    _pushHistory();
    _elements.removeAt(idx);
    _selectedIds.remove(id);
    _invalidateCache();
    _cachedSelectedIds = null;
    _bumpPaint();
  }

  /// Removes all currently-selected elements. Returns the count removed.
  int removeSelected() {
    if (_selectedIds.isEmpty) return 0;
    _pushHistory();
    final toRemove = Set<String>.of(_selectedIds);
    _elements.removeWhere((e) => toRemove.contains(e.id));
    _selectedIds.clear();
    _invalidateCache();
    _cachedSelectedIds = null;
    _bumpPaint();
    return toRemove.length;
  }

  /// Translates all selected elements by [delta]. Suitable for drag.
  /// Bracket a continuous drag with [beginDragSession] / [endDragSession]:
  /// the first call inside the session pushes the single history entry for
  /// the whole drag, later calls push nothing.
  void translateSelected(Offset delta) {
    if (_selectedIds.isEmpty || delta == Offset.zero) return;
    _commitDragHistory();
    for (var i = 0; i < _elements.length; i++) {
      final el = _elements[i];
      if (_selectedIds.contains(el.id)) {
        _elements[i] = el.translate(delta);
      }
    }
    _invalidateCache();
    _bumpPaint();
  }

  bool _dragInProgress = false;
  SketchSnapshot? _pendingDragSnapshot;

  /// Resizes a bounded element (rectangle/ellipse/diamond/triangle/sticky)
  /// by replacing its rect. No-op for non-bounded elements. Bracket a
  /// continuous resize drag with [beginDragSession] / [endDragSession]: the
  /// first call inside the session pushes the single history entry for the
  /// whole drag, later calls push nothing.
  void resizeElement(String id, Rect newRect) {
    final idx = _indexOf(id);
    if (idx < 0) return;
    final el = _elements[idx];
    SketchElement? updated;
    if (el is SketchRectangle) updated = el.copyWith(rect: newRect);
    if (el is SketchEllipse) updated = el.copyWith(rect: newRect);
    if (el is SketchDiamond) updated = el.copyWith(rect: newRect);
    if (el is SketchTriangle) updated = el.copyWith(rect: newRect);
    if (el is SketchSticky) updated = el.copyWith(rect: newRect);
    if (updated == null) return;
    _commitDragHistory();
    _elements[idx] = updated;
    _invalidateCache();
    _bumpPaint();
  }

  /// Moves a linear element's (line/arrow) [start] and/or [end] point.
  /// No-op for anything else. Bracket a continuous endpoint drag with
  /// [beginDragSession] / [endDragSession], exactly like [resizeElement].
  void updateLinear(String id, {Offset? start, Offset? end}) {
    if (start == null && end == null) return;
    final idx = _indexOf(id);
    if (idx < 0) return;
    final el = _elements[idx];
    final SketchElement? updated = switch (el) {
      SketchLine l => l.copyWith(start: start, end: end),
      SketchArrow a => a.copyWith(start: start, end: end),
      _ => null,
    };
    if (updated == null) return;
    // A pointer parked on a handle delivers plenty of zero-delta moves;
    // none of them should be what commits the drag's history entry.
    if (_endpointsOf(updated) == _endpointsOf(el)) return;
    _commitDragHistory();
    _elements[idx] = updated;
    _invalidateCache();
    _bumpPaint();
  }

  /// Restyles every selected element by running [transform] over its current
  /// style. Returns how many elements actually changed.
  ///
  /// The whole batch is a single history entry — [update] pushes one entry
  /// per call, so undoing one palette pick across a multi-element selection
  /// would otherwise take one `undo()` per element. Inside a drag session (a
  /// style slider being dragged) it commits the snapshot [beginDragSession]
  /// armed instead, so the whole drag collapses into that one entry — the
  /// same contract [translateSelected] and [resizeElement] follow.
  int applyStyleToSelected(SketchStyle Function(SketchStyle) transform) {
    if (_selectedIds.isEmpty) return 0;

    final restyled = <int, SketchElement>{};
    for (var i = 0; i < _elements.length; i++) {
      final el = _elements[i];
      if (!_selectedIds.contains(el.id)) continue;
      final style = transform(el.style);
      if (style == el.style) continue;
      restyled[i] = el.copyWithStyle(style);
    }
    if (restyled.isEmpty) return 0;

    if (_dragInProgress) {
      _commitDragHistory();
    } else {
      _pushHistory();
    }
    restyled.forEach((i, el) => _elements[i] = el);
    _invalidateCache();
    _bumpPaint();
    return restyled.length;
  }

  /// Arms a single history snapshot for a drag/resize.
  ///
  /// The snapshot is taken now but only *pushed* by the first mutation the
  /// drag actually performs (see [_commitDragHistory]). Pushing it eagerly
  /// meant a plain click-to-select — which opens a move session that may
  /// never move — left an entry behind, so `canUndo` flipped true and the
  /// user's first undo visibly did nothing.
  void beginDragSession() {
    if (_dragInProgress) return;
    _dragInProgress = true;
    _pendingDragSnapshot = _currentSnapshot();
  }

  /// Marks the end of a drag session, discarding the armed snapshot when the
  /// drag never changed anything. No-op if none active.
  void endDragSession() {
    _dragInProgress = false;
    _pendingDragSnapshot = null;
  }

  /// Pushes the snapshot [beginDragSession] armed, the first time the drag
  /// mutates something. Later calls in the same session are no-ops, so one
  /// continuous drag stays exactly one history entry.
  void _commitDragHistory() {
    final pending = _pendingDragSnapshot;
    if (pending == null) return;
    _pendingDragSnapshot = null;
    _history.push(pending);
  }

  /// Swaps in a whole new scene as the canvas's *starting* state, discarding
  /// undo/redo history along with it.
  ///
  /// This is what opening a saved project uses, and the discard is the point:
  /// [replaceAll] snapshots the outgoing scene, so an undo straight after a
  /// project switch would pull the *previous* project's elements onto this
  /// canvas — which autosave would then persist into the wrong file. Any
  /// in-flight drag or text edit is abandoned too, since it belongs to a
  /// scene that is no longer on screen.
  ///
  /// [droppedOnLoad] is how many elements the file held that could not be
  /// decoded (see [SketchSerializer.load]). Pass it, and the scene is marked
  /// [sceneIsPartial] until [acknowledgePartialScene] clears it — see that
  /// getter for what the caller owes the user before saving.
  void loadScene(
    Iterable<SketchElement> newElements, {
    int droppedOnLoad = 0,
  }) {
    _elements
      ..clear()
      ..addAll(newElements);
    _droppedOnLoad = droppedOnLoad;
    _selectedIds.clear();
    _history.clear();
    _dragInProgress = false;
    _pendingDragSnapshot = null;
    _editingElementId = null;
    _editingCanvasPosition = null;
    _invalidateCache();
    _cachedSelectedIds = null;
    _bumpPaint();
  }

  /// Replaces the entire element list. Snapshots prior state.
  void replaceAll(Iterable<SketchElement> newElements) {
    _pushHistory();
    _elements
      ..clear()
      ..addAll(newElements);
    _invalidateCache();
    _bumpPaint();
  }

  void clear() {
    if (_elements.isEmpty && _selectedIds.isEmpty) return;
    _pushHistory();
    _elements.clear();
    _selectedIds.clear();
    _invalidateCache();
    _cachedSelectedIds = null;
    _bumpPaint();
  }

  /// Accepts the loss reported by [sceneIsPartial], re-arming autosave.
  ///
  /// Only the user can make this call — it is the moment their file stops
  /// containing the elements this build could not read.
  void acknowledgePartialScene() {
    if (_droppedOnLoad == 0) return;
    _droppedOnLoad = 0;
    notifyListeners();
  }

  // ── Duplicate / clipboard ──────────────────────────────────────────────

  /// Duplicates every selected element, offset by [offset], and leaves the
  /// copies selected in the originals' place. Returns how many were made.
  ///
  /// One history entry for the whole batch, like [applyStyleToSelected].
  int duplicateSelected({Offset offset = const Offset(16, 16)}) {
    final sources = _selectedInOrder();
    if (sources.isEmpty) return 0;
    _pushHistory();
    return _addCopies(sources, offset);
  }

  /// The current selection as a [SketchSerializer] payload for the system
  /// clipboard, or `null` when nothing is selected.
  ///
  /// The scene format rather than a bespoke one, so a selection copied in
  /// one FlowCraft window pastes into another — and into a saved `.json`
  /// scene — with no second parser to keep in step with this one.
  String? copySelectionToJson() {
    final selected = _selectedInOrder();
    if (selected.isEmpty) return null;
    return SketchSerializer.serialize(selected);
  }

  /// Adds the elements encoded in [json] with fresh ids and selects them.
  /// Returns how many were added, or `0` if the payload is unusable.
  ///
  /// [json] is whatever the system clipboard happened to hold, so this never
  /// throws into the UI: text that isn't JSON, JSON that isn't a scene, and
  /// a scene from a newer schema version all give `0`, while individual
  /// unparseable elements are skipped the way opening a file skips them.
  /// A paste dropping elements is *not* the data-loss case [sceneIsPartial]
  /// guards — nothing is being overwritten, so it stays out of that flag.
  ///
  /// [offset] translates every pasted element rather than positioning them
  /// absolutely (pass `Offset.zero` to paste in place). It defaults to the
  /// nudge [duplicateSelected] uses, so a paste back into the window it was
  /// copied from doesn't land invisibly on top of the original.
  int pasteFromJson(String json, {Offset? offset}) {
    final List<SketchElement> parsed;
    try {
      parsed = SketchSerializer.loadJson(json).elements;
    } catch (_) {
      return 0;
    }
    if (parsed.isEmpty) return 0;
    _pushHistory();
    return _addCopies(parsed, offset ?? const Offset(16, 16));
  }

  // ── Z-order ────────────────────────────────────────────────────────────

  /// Moves the selection above everything else, keeping the selected
  /// elements in the order they already had relative to each other.
  void bringToFront() {
    if (_selectedIds.isEmpty) return;
    final (selected, others) = _partitionBySelection();
    _applyOrder([...others, ...selected]);
  }

  /// Moves the selection below everything else, preserving its internal
  /// order.
  void sendToBack() {
    if (_selectedIds.isEmpty) return;
    final (selected, others) = _partitionBySelection();
    _applyOrder([...selected, ...others]);
  }

  /// Moves the selection one step up the stack.
  ///
  /// A non-contiguous selection travels as independent runs: each contiguous
  /// block steps over the single unselected element above it, so a block
  /// already at the top stays put while the others still advance. The
  /// alternative — compacting the selection into one block — would reorder
  /// elements the user never selected, which is a far bigger surprise than
  /// one block not moving.
  void bringForward() {
    if (_selectedIds.isEmpty) return;
    final next = List<SketchElement>.of(_elements);
    // Top-down, so moving one run can't disturb a run not yet visited.
    var i = next.length - 1;
    while (i >= 0) {
      if (!_selectedIds.contains(next[i].id)) {
        i--;
        continue;
      }
      final end = i;
      while (i >= 0 && _selectedIds.contains(next[i].id)) {
        i--;
      }
      // Drop the blocker below the run instead of moving the run itself:
      // one list operation, and the run's internal order can't shift.
      if (end < next.length - 1) next.insert(i + 1, next.removeAt(end + 1));
    }
    _applyOrder(next);
  }

  /// Moves the selection one step down the stack — the mirror of
  /// [bringForward], including its run-by-run rule.
  void sendBackward() {
    if (_selectedIds.isEmpty) return;
    final next = List<SketchElement>.of(_elements);
    var i = 0;
    while (i < next.length) {
      if (!_selectedIds.contains(next[i].id)) {
        i++;
        continue;
      }
      final start = i;
      while (i < next.length && _selectedIds.contains(next[i].id)) {
        i++;
      }
      if (start > 0) next.insert(i - 1, next.removeAt(start - 1));
    }
    _applyOrder(next);
  }

  // ── Grouping ───────────────────────────────────────────────────────────

  /// Puts every selected element into one new group.
  ///
  /// A selection spanning several existing groups is *flattened* into the
  /// new one rather than nested inside it: [SketchElement.groupId] is a flat
  /// field with no parent to nest into, and faking a hierarchy on top of it
  /// would leave the gesture layer guessing which level a click selects.
  void groupSelected() {
    // A group of one is just the element; grouping it would only cost an
    // undo entry that changes nothing the user can see.
    if (_selectedIds.length < 2) return;
    if (_selectionIsExactlyOneGroup()) return;

    final groupId = IdGenerator.generate('group');
    final grouped = <int, SketchElement>{};
    for (var i = 0; i < _elements.length; i++) {
      final el = _elements[i];
      if (!_selectedIds.contains(el.id)) continue;
      grouped[i] = el.withGroupId(groupId);
    }
    if (grouped.isEmpty) return;

    _pushHistory();
    grouped.forEach((i, el) => _elements[i] = el);
    _invalidateCache();
    _bumpPaint();
  }

  /// Clears the group of every selected element. No-op when none is grouped.
  void ungroupSelected() {
    if (_selectedIds.isEmpty) return;
    final ungrouped = <int, SketchElement>{};
    for (var i = 0; i < _elements.length; i++) {
      final el = _elements[i];
      if (!_selectedIds.contains(el.id) || el.groupId == null) continue;
      ungrouped[i] = el.withGroupId(null);
    }
    if (ungrouped.isEmpty) return;

    _pushHistory();
    ungrouped.forEach((i, el) => _elements[i] = el);
    _invalidateCache();
    _bumpPaint();
  }

  /// Expands [ids] to include every element sharing a group with any of
  /// them, so clicking one member selects the whole group.
  ///
  /// Called from pointer-down on every click, so it runs off a group index
  /// built once per scene mutation rather than scanning the element list.
  /// Ids that aren't on the canvas pass through untouched — [selectMany] is
  /// what validates them.
  Set<String> expandToGroups(Iterable<String> ids) {
    final groups = _groups;
    if (groups.isEmpty) return ids.toSet();
    final expanded = <String>{};
    for (final id in ids) {
      expanded.add(id);
      final members = groups[id];
      if (members != null) expanded.addAll(members);
    }
    return expanded;
  }

  // ── Selection (NOT history-tracked) ────────────────────────────────────

  void select(String id, {bool clearExisting = true}) {
    if (clearExisting) _selectedIds.clear();
    if (!_elements.any((e) => e.id == id)) return;
    _selectedIds.add(id);
    _cachedSelectedIds = null;
    notifyListeners();
  }

  void selectMany(Iterable<String> ids, {bool clearExisting = true}) {
    if (clearExisting) _selectedIds.clear();
    final valid = _elements.map((e) => e.id).toSet();
    for (final id in ids) {
      if (valid.contains(id)) _selectedIds.add(id);
    }
    _cachedSelectedIds = null;
    notifyListeners();
  }

  void deselect(String id) {
    if (_selectedIds.remove(id)) {
      _cachedSelectedIds = null;
      notifyListeners();
    }
  }

  void clearSelection() {
    if (_selectedIds.isEmpty) return;
    _selectedIds.clear();
    _cachedSelectedIds = null;
    notifyListeners();
  }

  /// Selects elements whose bounds intersect [region] (marquee selection).
  void selectInRegion(Rect region, {bool addToSelection = false}) {
    if (!addToSelection) _selectedIds.clear();
    final hits = SketchHitTest.intersecting(_elements, region);
    for (final e in hits) {
      _selectedIds.add(e.id);
    }
    _cachedSelectedIds = null;
    notifyListeners();
  }

  // ── Text editing ───────────────────────────────────────────────────────

  /// Begins editing the text of an existing bounded shape or text
  /// element. If [canvasPosition] is provided, the next [commitTextEdit]
  /// will create a fresh [SketchText] anchored there instead.
  void beginTextEdit({String? elementId, Offset? canvasPosition}) {
    if (elementId == null && canvasPosition == null) return;
    _editingElementId = elementId;
    _editingCanvasPosition = canvasPosition;
    if (elementId != null) {
      select(elementId);
    }
    notifyListeners();
  }

  /// Commits [text] to the element currently being edited. Empty input
  /// removes the text from a bounded shape, or skips creation for a
  /// pending new [SketchText].
  void commitTextEdit(String text) {
    final id = _editingElementId;
    final pos = _editingCanvasPosition;

    _editingElementId = null;
    _editingCanvasPosition = null;

    final trimmed = text.trim();

    if (id != null) {
      final idx = _indexOf(id);
      if (idx >= 0) {
        final el = _elements[idx];
        // Empty text on a SketchText → remove it entirely.
        if (el is SketchText && trimmed.isEmpty) {
          _pushHistory();
          _elements.removeAt(idx);
          _selectedIds.remove(id);
          _invalidateCache();
          _cachedSelectedIds = null;
          _bumpPaint();
          return;
        }
        final updated = _withText(el, trimmed.isEmpty ? null : trimmed);
        if (updated != null) {
          _pushHistory();
          _elements[idx] = updated;
          _invalidateCache();
          _bumpPaint();
          return;
        }
      }
    } else if (pos != null && trimmed.isNotEmpty) {
      add(SketchText.create(
        position: pos,
        text: trimmed,
        style: _currentStyle,
      ));
      return;
    }

    notifyListeners();
  }

  void cancelTextEdit() {
    if (_editingElementId == null && _editingCanvasPosition == null) return;
    _editingElementId = null;
    _editingCanvasPosition = null;
    notifyListeners();
  }

  SketchElement? _withText(SketchElement el, String? text) {
    switch (el) {
      case SketchRectangle r:
        return r.copyWith(text: text);
      case SketchEllipse e:
        return e.copyWith(text: text);
      case SketchDiamond d:
        return d.copyWith(text: text);
      case SketchTriangle tri:
        return tri.copyWith(text: text);
      case SketchSticky s:
        return s.copyWith(text: text);
      case SketchText t:
        if (text == null || text.isEmpty) {
          // Empty text on a SketchText → remove it.
          return null;
        }
        return t.copyWith(text: text);
      default:
        return null;
    }
  }

  // ── Undo / redo ────────────────────────────────────────────────────────

  void undo() {
    final snap = _history.popUndo(_currentSnapshot());
    if (snap == null) return;
    _applySnapshot(snap);
  }

  void redo() {
    final snap = _history.popRedo(_currentSnapshot());
    if (snap == null) return;
    _applySnapshot(snap);
  }

  // ── internal ───────────────────────────────────────────────────────────

  int _indexOf(String id) {
    for (var i = 0; i < _elements.length; i++) {
      if (_elements[i].id == id) return i;
    }
    return -1;
  }

  /// Endpoints of a linear element, `null` for anything else.
  static (Offset, Offset)? _endpointsOf(SketchElement el) => switch (el) {
        SketchLine l => (l.start, l.end),
        SketchArrow a => (a.start, a.end),
        _ => null,
      };

  /// Selected elements in stacking order — the order they were drawn in,
  /// not the order they happen to have been clicked in.
  List<SketchElement> _selectedInOrder() => [
        for (final el in _elements)
          if (_selectedIds.contains(el.id)) el,
      ];

  (List<SketchElement>, List<SketchElement>) _partitionBySelection() {
    final selected = <SketchElement>[];
    final others = <SketchElement>[];
    for (final el in _elements) {
      (_selectedIds.contains(el.id) ? selected : others).add(el);
    }
    return (selected, others);
  }

  /// Appends fresh-id copies of [sources] on top of the stack and selects
  /// them, returning the count. Callers push history first, so duplicate and
  /// paste each stay exactly one entry.
  int _addCopies(List<SketchElement> sources, Offset offset) {
    final copies = _reidentify(sources, offset);
    _elements.addAll(copies);
    _selectedIds
      ..clear()
      ..addAll(copies.map((e) => e.id));
    _invalidateCache();
    _cachedSelectedIds = null;
    _bumpPaint();
    return copies.length;
  }

  /// Copies [sources] with fresh ids, remapped groups, and an [offset] shift.
  ///
  /// Ids are minted against the ids already on the canvas, because a paste
  /// of a selection copied from *this* scene arrives carrying the originals'
  /// ids — and two elements sharing an id hand selection, hit-testing and
  /// MCP addressing a single handle for both.
  ///
  /// A group among [sources] is copied as a *new* group for the same reason:
  /// reusing the source group id would fuse the copies to the originals, so
  /// dragging one would drag the other.
  List<SketchElement> _reidentify(List<SketchElement> sources, Offset offset) {
    final taken = <String>{for (final el in _elements) el.id};
    final groups = <String, String>{};
    final copies = <SketchElement>[];
    for (final source in sources) {
      var id = IdGenerator.generate('sketch');
      while (!taken.add(id)) {
        id = IdGenerator.generate('sketch');
      }
      var copy = source.withId(id);
      final group = source.groupId;
      if (group != null) {
        copy = copy.withGroupId(
          groups.putIfAbsent(group, () => IdGenerator.generate('group')),
        );
      }
      copies.add(offset == Offset.zero ? copy : copy.translate(offset));
    }
    return copies;
  }

  /// Commits a reordered element list as one history entry, or does nothing
  /// when the order is unchanged — a z-order command on a selection already
  /// at the top would otherwise leave an entry that undoes nothing visible.
  void _applyOrder(List<SketchElement> next) {
    var changed = false;
    for (var i = 0; i < next.length; i++) {
      if (!identical(next[i], _elements[i])) {
        changed = true;
        break;
      }
    }
    if (!changed) return;
    _pushHistory();
    _elements
      ..clear()
      ..addAll(next);
    _invalidateCache();
    _bumpPaint();
  }

  /// Element id → every id in that element's group, itself included.
  ///
  /// Rebuilt once per scene mutation rather than per lookup, because
  /// [expandToGroups] runs on every pointer-down. Members of one group share
  /// a single list instance, so the index costs one map entry per grouped
  /// element and copies nothing.
  Map<String, List<String>> get _groups => _cachedGroups ??= _buildGroups();

  Map<String, List<String>> _buildGroups() {
    final byGroup = <String, List<String>>{};
    for (final el in _elements) {
      final group = el.groupId;
      if (group == null) continue;
      (byGroup[group] ??= <String>[]).add(el.id);
    }
    final index = <String, List<String>>{};
    for (final members in byGroup.values) {
      for (final id in members) {
        index[id] = members;
      }
    }
    return index;
  }

  /// Whether the selection is exactly the membership of one existing group.
  /// Regrouping that changes only the group's id, which the user sees as an
  /// undo entry that does nothing.
  bool _selectionIsExactlyOneGroup() {
    List<String>? members;
    var selected = 0;
    for (final el in _elements) {
      if (!_selectedIds.contains(el.id)) continue;
      final group = _groups[el.id];
      // Ungrouped, or a second group in the selection: a real regroup.
      if (group == null || (members != null && !identical(group, members))) {
        return false;
      }
      members = group;
      selected++;
    }
    return members != null && members.length == selected;
  }

  void _invalidateCache() {
    _cachedElements = null;
    _cachedGroups = null;
  }

  void _bumpPaint() {
    _paintGen++;
    notifyListeners();
  }

  void _pushHistory() {
    _history.push(_currentSnapshot());
  }

  SketchSnapshot _currentSnapshot() {
    return SketchSnapshot(
      elements: List<SketchElement>.unmodifiable(_elements),
      selectedIds: Set<String>.unmodifiable(_selectedIds),
    );
  }

  void _applySnapshot(SketchSnapshot snap) {
    _elements
      ..clear()
      ..addAll(snap.elements);
    _selectedIds
      ..clear()
      ..addAll(snap.selectedIds);
    _invalidateCache();
    _cachedSelectedIds = null;
    _bumpPaint();
  }

  @override
  void dispose() {
    _history.clear();
    super.dispose();
  }
}

/// App-wide [SketchController] instance, for dependency injection only —
/// this provider is NOT reactive (Riverpod 3 dropped `ChangeNotifierProvider`
/// from its public API). Widgets that need to rebuild on canvas changes
/// keep using `SketchController`'s own `ChangeNotifier`/`addListener`
/// mechanism directly, exactly as `WhiteboardCanvas` and
/// `SketchToolbarRich` already do.
final sketchControllerProvider = Provider<SketchController>((ref) {
  final controller = SketchController(currentTool: SketchTool.select);
  ref.onDispose(controller.dispose);
  return controller;
});
