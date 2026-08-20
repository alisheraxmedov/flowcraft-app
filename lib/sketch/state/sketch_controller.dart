import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Rect;
import 'dart:ui' show Offset;

import 'package:flowcraft/sketch/domain/sketch_hit_test.dart';
import 'package:flowcraft/sketch/models/sketch_element.dart';
import 'package:flowcraft/sketch/models/sketch_style.dart';
import 'package:flowcraft/sketch/models/sketch_tool.dart';
import 'package:flowcraft/sketch/state/sketch_history.dart';

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

  List<SketchElement>? _cachedElements;
  Set<String>? _cachedSelectedIds;

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
  /// Calls *without* pushing history mid-drag — call [beginDragSession] /
  /// [endDragSession] to bracket a continuous drag.
  void translateSelected(Offset delta) {
    if (_selectedIds.isEmpty || delta == Offset.zero) return;
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

  /// Resizes a bounded element (rectangle/ellipse/diamond/triangle/sticky)
  /// by replacing its rect. No-op for non-bounded elements. History is NOT
  /// pushed here — call [beginDragSession] / [endDragSession] around a
  /// continuous resize drag.
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
    _elements[idx] = updated;
    _invalidateCache();
    _bumpPaint();
  }

  /// Pushes a single history snapshot at the start of a drag/resize.
  void beginDragSession() {
    if (_dragInProgress) return;
    _pushHistory();
    _dragInProgress = true;
  }

  /// Marks the end of a drag session. No-op if none active.
  void endDragSession() {
    _dragInProgress = false;
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

  void _invalidateCache() {
    _cachedElements = null;
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
