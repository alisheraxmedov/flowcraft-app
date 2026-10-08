import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Axis, Rect;
import 'dart:ui' show Offset;

import 'package:flowcraft/core/domain/arrow_binding.dart';
import 'package:flowcraft/core/domain/frame_membership.dart';
import 'package:flowcraft/core/domain/sketch_hit_test.dart';
import 'package:flowcraft/core/serialization/sketch_serializer.dart';
import 'package:flowcraft/core/utils/id_generator.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/models/sketch_tool.dart';
import 'package:flowcraft/viewmodels/sketch_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which edge or centre line [SketchController.alignSelected] lines up on.
enum AlignEdge { left, centerX, right, top, centerY, bottom }

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
  }) : _elements = [...?initialElements],
       _currentTool = currentTool,
       _currentStyle = currentStyle,
       _history = SketchHistory(maxHistory: maxHistory);

  final List<SketchElement> _elements;
  final Set<String> _selectedIds = <String>{};
  final SketchHistory _history;

  SketchTool _currentTool;
  SketchStyle _currentStyle;

  int _paintGen = 0;

  ({Rect rect, bool onlyIfHidden})? _frameRequest;
  int _frameRequestGen = 0;

  Iterable<String> _revealRequest = const [];
  int _revealGen = 0;

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

  /// Latest canvas-space rect the view was asked to bring on screen, or
  /// `null` before any request. See [requestFrame].
  ({Rect rect, bool onlyIfHidden})? get frameRequest => _frameRequest;

  /// Bumped by every accepted [requestFrame]. A counter rather than a value
  /// so "fit, pan away, fit again" is two distinct events for the view.
  int get frameRequestGen => _frameRequestGen;

  /// Ids the view was last asked to animate in. See [requestReveal].
  Iterable<String> get revealRequest => _revealRequest;

  /// Bumped by every [requestReveal], so two reveals of equal ids are two
  /// events for the view.
  int get revealGen => _revealGen;

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

  /// Replaces every element whose id matches one in [elements], as a single
  /// history entry, and returns how many were actually replaced.
  ///
  /// The batch sibling of [update], the way [addAll] is [add]'s: [update]
  /// pushes one history entry per call, so an MCP `flowcraft_update`
  /// correcting five shapes at once would otherwise cost five `undo()`s to
  /// take back — and would let a mid-batch failure leave a half-applied
  /// scene behind a run of undo entries. Ids not on the canvas are skipped
  /// rather than added, so a patch that addresses only stale ids changes
  /// nothing. Like [addAll], it snapshots and bumps paint only when at least
  /// one element matched, so an all-stale batch leaves no empty undo entry.
  int updateAll(Iterable<SketchElement> elements) {
    final replacements = <int, SketchElement>{};
    for (final element in elements) {
      final idx = _indexOf(element.id);
      if (idx < 0) continue;
      replacements[idx] = element;
    }
    if (replacements.isEmpty) return 0;
    _pushHistory();
    replacements.forEach((i, el) => _elements[i] = el);
    _invalidateCache();
    _bumpPaint();
    return replacements.length;
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

  /// Removes every element whose id is in [ids], as a single history entry,
  /// and returns how many were removed.
  ///
  /// The batch sibling of [remove], modelled on [removeSelected]: an MCP
  /// `flowcraft_delete` naming several ids should be one undo, not one per
  /// id. Deleted ids are also dropped from the selection, the way [remove]
  /// drops the one it takes, so a selection can't outlive the element it
  /// pointed at. Ids not on the canvas are ignored, and when none match it
  /// makes no history entry and no paint bump — an all-stale delete is a
  /// genuine no-op rather than an empty undo step.
  int removeIds(Iterable<String> ids) {
    final target = ids.toSet();
    if (target.isEmpty) return 0;
    final survivors = <SketchElement>[
      for (final el in _elements)
        if (!target.contains(el.id)) el,
    ];
    final removed = _elements.length - survivors.length;
    if (removed == 0) return 0;
    _pushHistory();
    _elements
      ..clear()
      ..addAll(survivors);
    _selectedIds.removeAll(target);
    _invalidateCache();
    _cachedSelectedIds = null;
    _bumpPaint();
    return removed;
  }

  /// Translates all selected elements by [delta]. Suitable for drag.
  /// Bracket a continuous drag with [beginDragSession] / [endDragSession]:
  /// the first call inside the session pushes the single history entry for
  /// the whole drag, later calls push nothing.
  void translateSelected(Offset delta) {
    if (_selectedIds.isEmpty || delta == Offset.zero) return;
    _commitDragHistory();
    final moving = {..._selectedIds, ..._frameMembersToMove()};
    for (var i = 0; i < _elements.length; i++) {
      final el = _elements[i];
      if (moving.contains(el.id)) {
        var moved = el.translate(delta);
        // An arrow dragged without the shape it is bound to has been pulled
        // off it: that end unbinds, or reconcile would snap it straight back.
        if (moved is SketchArrow &&
            (moved.startBinding != null || moved.endBinding != null)) {
          final s = moved.startBinding;
          final e = moved.endBinding;
          moved = moved.copyWith(
            startBinding: s != null && moving.contains(s.elementId) ? s : null,
            endBinding: e != null && moving.contains(e.elementId) ? e : null,
          );
        }
        _elements[i] = moved;
      }
    }
    _invalidateCache();
    _bumpPaint();
  }

  /// Members of the selected frames that ride along with them. Captured once
  /// per drag session (the first move) so an element the frame passes over
  /// is not picked up mid-drag and a member is not dropped when it momentarily
  /// pokes out; outside a session (nudge) it is computed per call.
  Set<String> _frameMembersToMove() {
    final cached = _dragFrameMembers;
    if (cached != null) return cached;
    final ids = <String>{
      for (final f in _elements.whereType<SketchFrame>())
        if (_selectedIds.contains(f.id))
          for (final m in FrameMembership.members(f, _elements)) m.id,
    };
    if (_dragInProgress) _dragFrameMembers = ids;
    return ids;
  }

  Set<String>? _dragFrameMembers;
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
    if (el is SketchFrame) updated = el.copyWith(rect: newRect);
    if (el is SketchIcon) updated = el.copyWith(rect: newRect);
    if (el is SketchImage) updated = el.copyWith(rect: newRect);
    if (el is SketchEntity) updated = el.copyWith(rect: newRect);
    if (updated == null) return;
    _commitDragHistory();
    _elements[idx] = updated;
    _invalidateCache();
    _bumpPaint();
  }

  /// Collapses a sticky note to its badge, or expands it back to its bubble.
  ///
  /// No-op for any other element type, and for a note already in that state.
  /// The note's `rect` is untouched, which is what makes expanding restore
  /// the geometry the user had rather than a default.
  ///
  /// **Not history-tracked**, deliberately — see [collapseExpandedStickies],
  /// which is where most collapses come from.
  void setStickyCollapsed(String id, bool collapsed) {
    final idx = _indexOf(id);
    if (idx < 0) return;
    final el = _elements[idx];
    if (el is! SketchSticky || el.collapsed == collapsed) return;
    _elements[idx] = el.copyWith(collapsed: collapsed);
    _invalidateCache();
    _bumpPaint();
  }

  /// Collapses every expanded sticky note other than [except], returning
  /// how many it closed.
  ///
  /// This is what a click anywhere on the canvas does on its way down: a
  /// note stays open only while the pointer is on it. The caller passes the
  /// element the press landed on — the note itself, a handle of it — and
  /// everything else closes.
  ///
  /// Like [setStickyCollapsed], it leaves **no undo entry**. Open-or-closed
  /// is view state in the way selection is, not content: it is cheap to
  /// redo by hand (one click), it is a side-effect of clicks whose *purpose*
  /// was something else, and an entry for each of those would make Ctrl+Z
  /// unpredictable — the user clicks a rectangle, and their next undo
  /// reopens a note instead of undoing the thing they did to the rectangle.
  /// Unlike selection it *is* persisted, because a board's worth of notes
  /// should come back the way it was left; `paintGen` is bumped so autosave
  /// sees it.
  int collapseExpandedStickies({String? except}) {
    var closed = 0;
    for (var i = 0; i < _elements.length; i++) {
      final el = _elements[i];
      if (el is! SketchSticky || el.collapsed || el.id == except) continue;
      _elements[i] = el.copyWith(collapsed: true);
      closed++;
    }
    if (closed == 0) return 0;
    _invalidateCache();
    _bumpPaint();
    return closed;
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
    // Dragging an end pulls it off its shape; release re-binds through
    // [setArrowBindings].
    _elements[idx] = updated is SketchArrow
        ? updated.copyWith(
            startBinding: start != null ? null : updated.startBinding,
            endBinding: end != null ? null : updated.endBinding,
          )
        : updated;
    _invalidateCache();
    _bumpPaint();
  }

  /// Sets which shapes [id]'s arrow ends are attached to (`null` detaches).
  ///
  /// One undo entry restoring endpoints and bindings together, or none when
  /// nothing changes. Inside a drag session it joins the session's entry, so
  /// an endpoint drag that ends on a shape is still a single undo. The
  /// endpoints themselves are re-anchored by the reconcile in [_bumpPaint].
  void setArrowBindings(
    String id, {
    required SketchBinding? start,
    required SketchBinding? end,
  }) {
    final idx = _indexOf(id);
    if (idx < 0) return;
    final el = _elements[idx];
    if (el is! SketchArrow ||
        (el.startBinding == start && el.endBinding == end)) {
      return;
    }
    if (_dragInProgress) {
      _commitDragHistory();
    } else {
      _pushHistory();
    }
    _elements[idx] = el.copyWith(startBinding: start, endBinding: end);
    _invalidateCache();
    _bumpPaint();
  }

  // ── Align / distribute ─────────────────────────────────────────────────

  /// Selection as movable units: a group moves as one, anything else alone.
  /// Arrows with a binding are left out — they follow their shapes through
  /// the reconcile, and moving them here would unbind them.
  List<({List<int> indices, Rect rect})> _selectionUnits() {
    final ids = expandToGroups(_selectedIds);
    final byKey = <String, List<int>>{};
    for (var i = 0; i < _elements.length; i++) {
      final el = _elements[i];
      if (!ids.contains(el.id)) continue;
      if (el is SketchArrow &&
          (el.startBinding != null || el.endBinding != null)) {
        continue;
      }
      (byKey[el.groupId != null ? 'g:${el.groupId}' : 'e:${el.id}'] ??= []).add(
        i,
      );
    }
    return [
      for (final indices in byKey.values)
        (
          indices: indices,
          rect: indices
              .map((i) => _elements[i].bounds)
              .reduce((a, b) => a.expandToInclude(b)),
        ),
    ];
  }

  /// Translates units by their deltas as one history entry. Returns how many
  /// actually moved; none → no history entry and no paint bump.
  int _moveUnits(
    List<({List<int> indices, Rect rect})> units,
    List<Offset> deltas,
  ) {
    var moved = 0;
    for (final d in deltas) {
      if (d.distanceSquared > 1e-12) moved++;
    }
    if (moved == 0) return 0;
    _pushHistory();
    for (var u = 0; u < units.length; u++) {
      if (deltas[u].distanceSquared <= 1e-12) continue;
      for (final i in units[u].indices) {
        _elements[i] = _elements[i].translate(deltas[u]);
      }
    }
    _invalidateCache();
    _bumpPaint();
    return moved;
  }

  /// Lines every selected unit up on [edge] of the units' combined bounds, as
  /// one history entry. Returns how many units moved; needs at least two.
  int alignSelected(AlignEdge edge) {
    final units = _selectionUnits();
    if (units.length < 2) return 0;
    final ref = units.map((u) => u.rect).reduce((a, b) => a.expandToInclude(b));
    final deltas = [
      for (final u in units)
        switch (edge) {
          AlignEdge.left => Offset(ref.left - u.rect.left, 0),
          AlignEdge.right => Offset(ref.right - u.rect.right, 0),
          AlignEdge.centerX => Offset(ref.center.dx - u.rect.center.dx, 0),
          AlignEdge.top => Offset(0, ref.top - u.rect.top),
          AlignEdge.bottom => Offset(0, ref.bottom - u.rect.bottom),
          AlignEdge.centerY => Offset(0, ref.center.dy - u.rect.center.dy),
        },
    ];
    return _moveUnits(units, deltas);
  }

  /// Spaces the selected units evenly along [axis] with the first and last
  /// fixed, as one history entry. Returns how many moved; needs at least
  /// three units.
  int distributeSelected(Axis axis) {
    final units = _selectionUnits();
    if (units.length < 3) return 0;
    final horizontal = axis == Axis.horizontal;
    double lead(Rect r) => horizontal ? r.left : r.top;
    double size(Rect r) => horizontal ? r.width : r.height;
    units.sort((a, b) => lead(a.rect).compareTo(lead(b.rect)));
    final start = lead(units.first.rect);
    final end = lead(units.last.rect) + size(units.last.rect);
    final gap =
        (end - start - units.fold(0.0, (sum, u) => sum + size(u.rect))) /
        (units.length - 1);
    var cursor = start;
    final deltas = <Offset>[];
    for (final u in units) {
      final d = cursor - lead(u.rect);
      deltas.add(horizontal ? Offset(d, 0) : Offset(0, d));
      cursor += size(u.rect) + gap;
    }
    return _moveUnits(units, deltas);
  }

  // ── Frame requests ─────────────────────────────────────────────────────

  /// Asks the view to bring canvas-space [rect] on screen.
  ///
  /// A request, not viewport state — the controller deliberately knows
  /// nothing of the viewport. It only notifies: this is view state, so it
  /// must never reach [_bumpPaint] and trigger an autosave. Non-finite rects
  /// are ignored. [onlyIfHidden] marks an automatic reframe (an agent drew
  /// something); those are dropped mid-drag so the canvas doesn't move under
  /// the user's pointer.
  void requestFrame(Rect rect, {bool onlyIfHidden = false}) {
    if (!rect.isFinite) return;
    if (onlyIfHidden && _dragInProgress) return;
    _frameRequest = (rect: rect, onlyIfHidden: onlyIfHidden);
    _frameRequestGen++;
    notifyListeners();
  }

  /// Asks the view to animate the elements [ids] in.
  ///
  /// View-only, like [requestFrame]: it only notifies, never reaches
  /// [_bumpPaint], so no autosave and no history entry.
  void requestReveal(Iterable<String> ids) {
    _revealRequest = List<String>.unmodifiable(ids);
    _revealGen++;
    notifyListeners();
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
    _dragFrameMembers = null;
    _pendingDragSnapshot = null;
    _rearmDragSnapshot = false;
  }

  /// Set when a history entry from *outside* the drag — an MCP draw landing
  /// while the pointer is down — was pushed after [beginDragSession] armed
  /// its snapshot. That snapshot predates the foreign change, so pushing it
  /// would make the first undo after the drag rewind past the agent's
  /// elements; instead the drag re-snapshots at its first move.
  bool _rearmDragSnapshot = false;

  /// Pushes the snapshot [beginDragSession] armed, the first time the drag
  /// mutates something. Later calls in the same session are no-ops, so one
  /// continuous drag stays exactly one history entry.
  void _commitDragHistory() {
    if (_rearmDragSnapshot) {
      // Called before the mutation, so this is the scene as the foreign
      // change left it and the drag found it.
      _rearmDragSnapshot = false;
      _pendingDragSnapshot = null;
      _history.push(_currentSnapshot());
      return;
    }
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
  void loadScene(Iterable<SketchElement> newElements, {int droppedOnLoad = 0}) {
    _elements
      ..clear()
      ..addAll(newElements);
    _droppedOnLoad = droppedOnLoad;
    _selectedIds.clear();
    _history.clear();
    _dragInProgress = false;
    _dragFrameMembers = null;
    _pendingDragSnapshot = null;
    _rearmDragSnapshot = false;
    _editingElementId = null;
    _editingCanvasPosition = null;
    _invalidateCache();
    _cachedSelectedIds = null;
    _bumpPaint();
  }

  /// Replaces the entire element list. Snapshots prior state.
  ///
  /// Selection and any text edit survive only for elements that are still
  /// on the canvas by id afterwards. Leaving a stale selection behind let
  /// Delete report "2 removed", push an undo entry and trigger an autosave
  /// while removing nothing, after an MCP `replace` had swapped the scene
  /// under it.
  void replaceAll(Iterable<SketchElement> newElements) {
    _pushHistory();
    _elements
      ..clear()
      ..addAll(newElements);
    _selectedIds.removeWhere((id) => _indexOf(id) < 0);
    final editing = _editingElementId;
    if (editing != null && _indexOf(editing) < 0) {
      _editingElementId = null;
      _editingCanvasPosition = null;
    }
    _invalidateCache();
    _cachedSelectedIds = null;
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
    return pasteElements(parsed, offset: offset);
  }

  /// [pasteFromJson] for elements a caller has already decoded: fresh ids,
  /// remapped groups, one history entry, the copies selected. Returns how
  /// many were added.
  ///
  /// Exists so a file import that has *already* parsed its payload — to
  /// count what it could not read — doesn't hand the same text over to be
  /// parsed a second time on the UI isolate.
  int pasteElements(List<SketchElement> elements, {Offset? offset}) {
    if (elements.isEmpty) return 0;
    _pushHistory();
    return _addCopies(elements, offset ?? const Offset(16, 16));
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

  /// Selects [id], replacing the current selection unless [clearExisting]
  /// is false. An id that is not on the canvas selects nothing — but still
  /// clears, exactly as [selectMany] with no valid id does, so the three
  /// views of the selection ([selectedIds], [isSelected], [hasSelection])
  /// never disagree about what just happened.
  void select(String id, {bool clearExisting = true}) {
    final had = _selectedIds.isNotEmpty;
    if (clearExisting) _selectedIds.clear();
    if (_indexOf(id) < 0) {
      if (clearExisting && had) {
        _cachedSelectedIds = null;
        notifyListeners();
      }
      return;
    }
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
  ///
  /// Committing a sticky note also grows it to fit and collapses it — see
  /// [_withText]. [cancelTextEdit] does neither: commit is "I'm done with
  /// this note", cancel is "forget I started", and a cancelled edit leaves
  /// the note exactly as it found it. A cancelled note is not stranded
  /// open, though — the next click anywhere else closes it like any other
  /// expanded note ([collapseExpandedStickies]).
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
      add(
        SketchText.create(position: pos, text: trimmed, style: _currentStyle),
      );
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

  /// [el] as committing [text] to it leaves it.
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
        // Finishing a note grows it to fit what was typed and collapses it
        // to its badge. Collapsing on commit is what Enter gets — a click
        // away has already closed the note on its way down, through
        // `collapseExpandedStickies`, before the editor's commit fires, and
        // the `copyWith` below is then a no-op on that axis.
        //
        // An emptied note collapses like any other. It is not removed the
        // way an empty `SketchText` is: a `SketchText` *is* its text and has
        // nothing left when emptied, while a note the user deliberately
        // placed still has its colour, its position and its size. Nor does
        // it stay open as a visible reminder that it is blank — the one rule
        // the user can hold is "click away, it closes", and a note exempt
        // from that is a note that looks stuck.
        //
        // Fit before collapsing: `fittedToText` measures the *bubble*, and a
        // collapsed note has none to measure. Text, growth and collapse
        // land in one element, so the single history entry this commit
        // pushes undoes all three together.
        return s
            .copyWith(text: text, collapsed: false)
            .fittedToText()
            .copyWith(collapsed: true);
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

  /// Undo and redo both drop a snapshot armed by [beginDragSession]: it was
  /// taken against the scene *before* this jump, and letting the drag's
  /// next move push it would stack a stale pre-undo scene on top of the
  /// restored one — the first Ctrl+Z after the drag would then rewind to
  /// a state the user never saw. A drag still in progress re-snapshots at
  /// its next move instead, so it keeps an entry of its own.
  void undo() {
    final snap = _history.popUndo(_currentSnapshot());
    if (snap == null) return;
    _dropArmedSnapshot();
    _applySnapshot(snap);
  }

  void redo() {
    final snap = _history.popRedo(_currentSnapshot());
    if (snap == null) return;
    _dropArmedSnapshot();
    _applySnapshot(snap);
  }

  void _dropArmedSnapshot() {
    _pendingDragSnapshot = null;
    _rearmDragSnapshot = _dragInProgress;
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

  /// Re-anchors every bound arrow to its shape and clears bindings whose
  /// target is gone. Runs at the head of [_bumpPaint] — which every element
  /// mutation ends in — so no caller can forget it; it edits in place and
  /// never touches history, so the surrounding user action stays one entry.
  void _reconcileBindings() {
    Map<String, SketchElement>? byId;
    var changed = false;
    for (var i = 0; i < _elements.length; i++) {
      final el = _elements[i];
      if (el is! SketchArrow ||
          (el.startBinding == null && el.endBinding == null)) {
        continue;
      }
      byId ??= {for (final e in _elements) e.id: e};
      final resolved = ArrowBinding.resolve(el, byId);
      if (!identical(resolved, el)) {
        _elements[i] = resolved;
        changed = true;
      }
    }
    if (changed) _invalidateCache();
  }

  void _bumpPaint() {
    _reconcileBindings();
    _paintGen++;
    notifyListeners();
  }

  void _pushHistory() {
    _history.push(_currentSnapshot());
    if (_pendingDragSnapshot != null) {
      // A foreign entry landed under an armed drag — see
      // [_rearmDragSnapshot].
      _pendingDragSnapshot = null;
      _rearmDragSnapshot = true;
    }
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
