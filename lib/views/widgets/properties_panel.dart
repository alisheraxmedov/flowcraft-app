import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/core/theme/canvas_ink.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/models/icon_catalog.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/models/sketch_tool.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';
import 'package:flowcraft/views/widgets/glass/fc_switch.dart';
import 'package:flowcraft/views/widgets/glass/glass_island.dart';
import 'package:flowcraft/views/widgets/shortcuts/tool_shortcuts.dart';
import 'package:flowcraft/views/widgets/toolbar/palette_popover.dart';
import 'package:flowcraft/views/widgets/toolbar/style_popovers.dart';

/// The inspector island: edits the style (and, for a single element, the
/// geometry and kind-specific fields) of whatever is selected.
///
/// Shown for one or more selected elements — a multi-selection gets the style
/// sections only, with fields the elements disagree about shown as "mixed" —
/// and, with nothing selected while a drawing tool is active, edits the
/// pending [SketchController.currentStyle] the next element is drawn with.
/// Renders nothing otherwise.
///
/// Self-contained like [SketchToolbarRich] / [WhiteboardCanvas]: listens
/// to [controller] directly via `addListener` rather than through Riverpod,
/// so it can be dropped into any `Stack` without extra plumbing. It is 264
/// wide and as tall as its content (scrolling when the parent is shorter), so
/// the host should align it rather than stretch it.
class PropertiesPanel extends StatefulWidget {
  const PropertiesPanel({super.key, required this.controller});

  final SketchController controller;

  /// Shapes that carry an editable [Rect] (`.rect`) and can be resized via
  /// [SketchController.resizeElement]. Anything else (freedraw/line/arrow/
  /// text) only has the read-only [SketchElement.bounds] getter.
  static Rect? rectOf(SketchElement el) {
    if (el is SketchRectangle) return el.rect;
    if (el is SketchEllipse) return el.rect;
    if (el is SketchDiamond) return el.rect;
    if (el is SketchTriangle) return el.rect;
    if (el is SketchSticky) return el.rect;
    if (el is SketchFrame) return el.rect;
    if (el is SketchIcon) return el.rect;
    if (el is SketchEntity) return el.rect;
    return null;
  }

  @override
  State<PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends State<PropertiesPanel> {
  SketchController get _ctrl => widget.controller;

  /// Resolved live-theme colors for the current build — set at the top of
  /// [build] and read by every section builder below instead of reaching
  /// into `AppColors` (which only ever holds the dark palette) directly.
  late ColorScheme _colorScheme;

  final _xCtrl = TextEditingController();
  final _yCtrl = TextEditingController();
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();
  final _xFocus = FocusNode();
  final _yFocus = FocusNode();
  final _wFocus = FocusNode();
  final _hFocus = FocusNode();

  final _strokeHexCtrl = TextEditingController();
  final _fillHexCtrl = TextEditingController();
  final _strokeHexFocus = FocusNode();
  final _fillHexFocus = FocusNode();

  // Frame / entity name and the entity's attribute rows. Committed when the
  // field loses focus (or, for the single-line name, on submit) so typing
  // one word is one undo entry, not one per keystroke.
  final _nameCtrl = TextEditingController();
  final _attrsCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _attrsFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChange);
    for (final f in [_xFocus, _yFocus, _wFocus, _hFocus]) {
      f.addListener(_onDimensionFocusChange);
    }
    _strokeHexFocus.addListener(() {
      if (!_strokeHexFocus.hasFocus) _commitStrokeHex();
    });
    _fillHexFocus.addListener(() {
      if (!_fillHexFocus.hasFocus) _commitFillHex();
    });
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _commitName();
    });
    _attrsFocus.addListener(() {
      if (!_attrsFocus.hasFocus) _commitAttributes();
    });
  }

  @override
  void didUpdateWidget(PropertiesPanel old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChange);
    for (final c in [
      _xCtrl,
      _yCtrl,
      _wCtrl,
      _hCtrl,
      _strokeHexCtrl,
      _fillHexCtrl,
      _nameCtrl,
      _attrsCtrl,
    ]) {
      c.dispose();
    }
    for (final f in [
      _xFocus,
      _yFocus,
      _wFocus,
      _hFocus,
      _strokeHexFocus,
      _fillHexFocus,
      _nameFocus,
      _attrsFocus,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  /// Id of the element the fields currently hold values for. Every blur
  /// commit writes to THIS element, never to whatever is selected by the
  /// time the blur fires — otherwise typing in A then clicking B would write
  /// A's text onto B (and clearing the selection would lose the edit).
  String? _loadedId;
  bool _flushing = false;

  SketchElement? get _loaded {
    if (_loadedId == null) return null;
    for (final e in _ctrl.elements) {
      if (e.id == _loadedId) return e;
    }
    return null;
  }

  /// Error shown under the attributes box when two rows share a name.
  String? _attrsError;

  void _onChange() {
    if (!mounted) return;
    // Selection moved off the element being edited: commit whatever is still
    // pending in a focused field to the OLD element before the fields reload.
    if (!_flushing && _loadedId != null && _selected?.id != _loadedId) {
      _flushing = true;
      if ([_xFocus, _yFocus, _wFocus, _hFocus].any((f) => f.hasFocus)) {
        _commitDimensions();
      }
      if (_strokeHexFocus.hasFocus) _commitStrokeHex();
      if (_fillHexFocus.hasFocus) _commitFillHex();
      if (_nameFocus.hasFocus) _commitName();
      if (_attrsFocus.hasFocus) _commitAttributes();
      _flushing = false;
    }
    setState(() {});
  }

  // ── selection lookup ──────────────────────────────────────────────────

  SketchElement? get _selected {
    if (_ctrl.selectedIds.length != 1) return null;
    final id = _ctrl.selectedIds.single;
    for (final e in _ctrl.elements) {
      if (e.id == id) return e;
    }
    return null;
  }

  // ── dimensions & position ─────────────────────────────────────────────

  void _syncDimensionFields(SketchElement el, bool fresh) {
    final rect = PropertiesPanel.rectOf(el) ?? el.bounds;
    if (fresh || !_xFocus.hasFocus) _xCtrl.text = rect.left.toStringAsFixed(0);
    if (fresh || !_yFocus.hasFocus) _yCtrl.text = rect.top.toStringAsFixed(0);
    if (fresh || !_wFocus.hasFocus) _wCtrl.text = rect.width.toStringAsFixed(0);
    if (fresh || !_hFocus.hasFocus) {
      _hCtrl.text = rect.height.toStringAsFixed(0);
    }
  }

  void _onDimensionFocusChange() {
    final anyFocused = [
      _xFocus,
      _yFocus,
      _wFocus,
      _hFocus,
    ].any((f) => f.hasFocus);
    if (!anyFocused) _commitDimensions();
  }

  void _commitDimensions() {
    final el = _loaded;
    if (el == null) return;
    final rect = PropertiesPanel.rectOf(el);
    if (rect == null) return;
    final x = double.tryParse(_xCtrl.text) ?? rect.left;
    final y = double.tryParse(_yCtrl.text) ?? rect.top;
    final w = double.tryParse(_wCtrl.text) ?? rect.width;
    final h = double.tryParse(_hCtrl.text) ?? rect.height;
    final newRect = Rect.fromLTWH(x, y, w.abs(), h.abs());
    if (newRect != rect) {
      _ctrl.beginDragSession();
      _ctrl.resizeElement(el.id, newRect);
      _ctrl.endDragSession();
    }
  }

  // ── appearance ─────────────────────────────────────────────────────────

  static String _colorToHex(Color c) {
    final rgb = c.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static Color? _hexToColor(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 3) {
      h = h.split('').map((c) => '$c$c').join();
    }
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final value = int.tryParse(h, radix: 16);
    return value == null ? null : Color(value);
  }

  void _syncAppearanceFields(SketchElement el, bool fresh) {
    final style = el.style;
    if (fresh || !_strokeHexFocus.hasFocus) {
      _strokeHexCtrl.text = _colorToHex(style.strokeColor);
    }
    if (fresh || !_fillHexFocus.hasFocus) {
      _fillHexCtrl.text = style.fillColor == null
          ? ''
          : _colorToHex(style.fillColor!);
    }
  }

  void _commitStrokeHex() {
    if (_styleOnly) {
      final color = _hexToColor(_strokeHexCtrl.text);
      final same =
          !_disp.mixed.contains(_MixedField.strokeColor) &&
          color == _disp.style.strokeColor;
      if (color == null || same) return;
      _applyStyle((s) => s.copyWith(strokeColor: color));
      return;
    }
    final el = _loaded;
    if (el == null) return;
    final color = _hexToColor(_strokeHexCtrl.text);
    if (color == null || color == el.style.strokeColor) return;
    _ctrl.update(el.copyWithStyle(el.style.copyWith(strokeColor: color)));
  }

  void _commitFillHex() {
    final text = _fillHexCtrl.text.trim();
    if (_styleOnly) {
      final c = text.isEmpty ? null : _hexToColor(text);
      if (c == null && text.isNotEmpty) return;
      // A mixed field shows empty; that is not a request to clear the fill.
      if (c == null && _disp.mixed.contains(_MixedField.fillColor)) return;
      _applyStyle((s) => s.withFillColor(c));
      return;
    }
    final el = _loaded;
    if (el == null) return;
    // Same `withFillColor` rule the toolbar's fill palette uses, so a fill
    // set from here is just as visible as one set from there: a colour
    // promotes `FillStyle.none` to solid, an empty field clears both.
    final color = text.isEmpty ? null : _hexToColor(text);
    if (color == null && text.isNotEmpty) return;
    final style = el.style.withFillColor(color);
    if (style == el.style) return;
    _ctrl.update(el.copyWithStyle(style));
  }

  // ── style-only targets (multi-selection / drawing tool) ────────────────

  /// True while the panel edits a multi-selection or, with nothing selected,
  /// the pending [SketchController.currentStyle]: no single element owns the
  /// fields, so hex commits go through [_applyStyle] instead of `_loaded`.
  bool _styleOnly = false;

  /// What the style sections display this build, see [_resolveDisplayStyle].
  ({SketchStyle style, Set<_MixedField> mixed}) _disp = (
    style: const SketchStyle(),
    mixed: <_MixedField>{},
  );

  /// Thumb positions while a slider is being dragged. Mid-drag the local
  /// value wins: with a mixed selection the displayed (first element's)
  /// value would not move and the thumb would stick.
  double? _dragWidth;
  double? _dragRough;

  /// Applies a style pick to every selected element AND to the pending
  /// default for the next element drawn, as one undo entry (the batch goes
  /// through [SketchController.applyStyleToSelected]).
  void _applyStyle(SketchStyle Function(SketchStyle) transform) {
    _ctrl.applyStyleToSelected(transform);
    _ctrl.currentStyle = transform(_ctrl.currentStyle);
  }

  /// The style the panel should *display*, plus the fields a multi-element
  /// selection disagrees about (they render as "mixed" rather than letting
  /// whichever element comes first speak for all). With nothing selected it
  /// falls back to `currentStyle`, which is what the next element is drawn
  /// with. Display only: picks derive from each element's own style.
  ({SketchStyle style, Set<_MixedField> mixed}) _resolveDisplayStyle() {
    SketchStyle? first;
    final mixed = <_MixedField>{};
    for (final el in _ctrl.elements) {
      if (!_ctrl.isSelected(el.id)) continue;
      final s = el.style;
      if (first == null) {
        first = s;
        continue;
      }
      if (s.strokeColor != first.strokeColor) {
        mixed.add(_MixedField.strokeColor);
      }
      if (s.fillColor != first.fillColor) mixed.add(_MixedField.fillColor);
      if (s.strokeWidth != first.strokeWidth) {
        mixed.add(_MixedField.strokeWidth);
      }
      if (s.roughness != first.roughness) mixed.add(_MixedField.roughness);
      if (s.strokeStyle != first.strokeStyle) {
        mixed.add(_MixedField.strokeStyle);
      }
      if (s.fillStyle != first.fillStyle) mixed.add(_MixedField.fillStyle);
      if (mixed.length == _MixedField.values.length) break;
    }
    return (style: first ?? _ctrl.currentStyle, mixed: mixed);
  }

  void _syncStyleOnlyHex() {
    final style = _disp.style;
    final mixed = _disp.mixed;
    if (!_strokeHexFocus.hasFocus) {
      _strokeHexCtrl.text = mixed.contains(_MixedField.strokeColor)
          ? ''
          : _colorToHex(style.strokeColor);
    }
    if (!_fillHexFocus.hasFocus) {
      _fillHexCtrl.text =
          mixed.contains(_MixedField.fillColor) || style.fillColor == null
          ? ''
          : _colorToHex(style.fillColor!);
    }
  }

  /// Tools that draw something and therefore have a style to edit.
  static const _nonDrawing = {
    SketchTool.select,
    SketchTool.hand,
    SketchTool.eraser,
  };

  /// Header label + glyph for [el]; names match the tool that draws it.
  static (String, FcIcon) _kindOf(SketchElement el) => switch (el) {
    SketchRectangle() => ('Rectangle', FcIcons.square),
    SketchEllipse() => ('Ellipse', FcIcons.circle),
    SketchDiamond() => ('Diamond', FcIcons.diamond),
    SketchTriangle() => ('Triangle', FcIcons.triangle),
    SketchSticky() => ('Sticky note', FcIcons.stickyNote),
    SketchLine() => ('Line', FcIcons.lineDiagonal),
    SketchArrow() => ('Arrow', FcIcons.arrowUpRight),
    SketchFreedraw() => ('Drawing', FcIcons.pencil),
    SketchText() => ('Text', FcIcons.type),
    SketchFrame() => ('Frame', FcIcons.frame),
    SketchIcon() => ('Icon', FcIcons.shapes),
    SketchImage() => ('Image', FcIcons.image),
    SketchEntity() => ('Entity', FcIcons.square),
  };

  static FcIcon _toolIcon(SketchTool tool) => switch (tool) {
    SketchTool.rectangle => FcIcons.square,
    SketchTool.ellipse => FcIcons.circle,
    SketchTool.diamond => FcIcons.diamond,
    SketchTool.triangle => FcIcons.triangle,
    SketchTool.sticky => FcIcons.stickyNote,
    SketchTool.line => FcIcons.lineDiagonal,
    SketchTool.arrow => FcIcons.arrowUpRight,
    SketchTool.freedraw => FcIcons.pencil,
    SketchTool.text => FcIcons.type,
    SketchTool.frame => FcIcons.frame,
    SketchTool.icon => FcIcons.shapes,
    SketchTool.eraser => FcIcons.eraser,
    SketchTool.hand => FcIcons.hand,
    SketchTool.select => FcIcons.mousePointer2,
  };

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _colorScheme = Theme.of(context).colorScheme;
    final fc = context.fc;

    final el = _selected;
    final tool = _ctrl.currentTool;
    // Nothing selected and no drawing tool: nothing to edit. The fields keep
    // their `_loadedId` so a pending blur still commits to its element.
    if (el == null && !_ctrl.hasSelection && _nonDrawing.contains(tool)) {
      _styleOnly = false;
      return const SizedBox.shrink();
    }

    _styleOnly = el == null;
    _disp = _resolveDisplayStyle();
    if (el != null) {
      // A different element than the fields last loaded: reload every field
      // even if one still has focus (its pending text was flushed in
      // _onChange).
      final fresh = _loadedId != el.id;
      _syncDimensionFields(el, fresh);
      _syncAppearanceFields(el, fresh);
      _syncShapeFields(el, fresh);
      _loadedId = el.id;
    } else {
      _loadedId = null;
      _syncStyleOnlyHex();
    }

    final (title, glyph) = el != null
        ? _kindOf(el)
        : _ctrl.hasSelection
        ? ('${_ctrl.selectedIds.length} selected', FcIcons.mousePointer2)
        : ('${ToolShortcuts.labels[tool]} tool', _toolIcon(tool));
    final style = _disp.style;
    final mixed = _disp.mixed;
    final ink = inkFor(Theme.of(context).brightness);

    final sections = <Widget>[
      _header(fc, title, glyph),
      _colorSection(
        fc,
        'Stroke',
        'Stroke hex',
        _strokeHexCtrl,
        _strokeHexFocus,
        mixed.contains(_MixedField.strokeColor),
        hint: '#RRGGBB',
        swatches: [
          // The first swatch is the theme's ink (what new elements are drawn
          // in); it paints in the softer swatchInk token.
          for (final c in [ink, ...defaultPalette.skip(1)])
            Swatch(
              color: c,
              dot: c == ink ? fc.swatchInk : null,
              label: _colorToHex(c),
              current:
                  !mixed.contains(_MixedField.strokeColor) &&
                  style.strokeColor == c,
              onTap: () => _applyStyle((s) => s.copyWith(strokeColor: c)),
            ),
        ],
      ),
      _colorSection(
        fc,
        'Fill',
        'Fill hex',
        _fillHexCtrl,
        _fillHexFocus,
        mixed.contains(_MixedField.fillColor),
        hint: 'none',
        swatches: [
          for (final c in defaultFillPalette)
            Swatch(
              color: c,
              label: c == null ? 'No fill' : _colorToHex(c),
              current:
                  !mixed.contains(_MixedField.fillColor) &&
                  style.fillColor == c,
              onTap: () => _applyStyle((s) => s.withFillColor(c)),
            ),
        ],
      ),
      _sliderBlock(
        fc,
        'Stroke width',
        style.strokeWidth,
        1,
        12,
        22,
        mixed.contains(_MixedField.strokeWidth),
        _dragWidth,
        (v) => _dragWidth = v,
        (s, v) => s.copyWith(strokeWidth: v),
      ),
      _sliderBlock(
        fc,
        'Roughness',
        style.roughness,
        0,
        2.5,
        25,
        mixed.contains(_MixedField.roughness),
        _dragRough,
        (v) => _dragRough = v,
        (s, v) => s.copyWith(roughness: v),
      ),
      _titled(
        fc,
        'Stroke style',
        _GlyphSegmented<StrokeStyle>(
          value: mixed.contains(_MixedField.strokeStyle)
              ? null
              : style.strokeStyle,
          height: 44,
          gap: 6,
          items: [
            _Seg(
              StrokeStyle.solid,
              StyleLabels.strokeStyle[StrokeStyle.solid]!,
              FcIcons.strokeSolid,
              28,
            ),
            _Seg(
              StrokeStyle.dashed,
              StyleLabels.strokeStyle[StrokeStyle.dashed]!,
              FcIcons.strokeDashed,
              28,
            ),
            _Seg(
              StrokeStyle.dotted,
              StyleLabels.strokeStyle[StrokeStyle.dotted]!,
              FcIcons.strokeDotted,
              28,
            ),
          ],
          onChanged: (v) => _applyStyle((s) => s.copyWith(strokeStyle: v)),
        ),
      ),
      _titled(
        fc,
        'Fill style',
        _GlyphSegmented<FillStyle>(
          value: mixed.contains(_MixedField.fillStyle) ? null : style.fillStyle,
          height: 46,
          gap: 5,
          autoWidth: true,
          items: [
            _Seg(
              FillStyle.none,
              StyleLabels.fillStyle[FillStyle.none]!,
              FcIcons.fillNone,
              22,
            ),
            _Seg(
              FillStyle.solid,
              StyleLabels.fillStyle[FillStyle.solid]!,
              FcIcons.fillSolid,
              22,
            ),
            _Seg(
              FillStyle.hachure,
              StyleLabels.fillStyle[FillStyle.hachure]!,
              FcIcons.fillHachure,
              22,
            ),
            _Seg(
              FillStyle.crossHatch,
              StyleLabels.fillStyle[FillStyle.crossHatch]!,
              FcIcons.fillCrossHatch,
              22,
            ),
          ],
          onChanged: (v) => _applyStyle((s) => s.withFillStyle(v)),
        ),
      ),
      if (el != null) ...[
        if (el is SketchArrow) _arrowSection(fc, el),
        _dimensionsSection(fc, PropertiesPanel.rectOf(el) != null),
        ..._kindSection(fc, el),
        _fontSection(fc, el),
        _editJsonButton(fc, el),
      ],
    ];

    return SizedBox(
      width: 264,
      child: GlassIsland(
        strong: true,
        padding: const EdgeInsets.all(14),
        // Scrolls once the window is shorter than the content, but shrinks
        // to the content otherwise (a bare SingleChildScrollView would
        // always fill the height it is given).
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, w) in sections.indexed) ...[
                  if (i > 0) const SizedBox(height: 14),
                  w,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(FcTokens fc, String title, FcIcon glyph) {
    return Row(
      children: [
        FcIconGlyph(glyph, size: 16, color: fc.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.uiTitle.copyWith(
              color: fc.text,
              height: 20 / 14,
            ),
          ),
        ),
      ],
    );
  }

  /// Uppercase section label, 11/600 muted.
  Widget _label(FcTokens fc, String text) => Text(
    text.toUpperCase(),
    style: AppTypography.uiLabel.copyWith(color: fc.muted),
  );

  /// A 20px label row over [child].
  Widget _titled(FcTokens fc, String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 20,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _label(fc, label),
          ),
        ),
        child,
      ],
    );
  }

  /// "STROKE" / "FILL": label + 78x28 hex field over a 5-column swatch grid.
  Widget _colorSection(
    FcTokens fc,
    String label,
    String semanticLabel,
    TextEditingController ctrl,
    FocusNode focus,
    bool mixed, {
    required String hint,
    required List<Widget> swatches,
  }) {
    final isFill = label == 'Fill';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label(fc, label),
              SizedBox(
                width: 78,
                height: 28,
                child: TextField(
                  key: ValueKey('properties_hex_$label'),
                  controller: ctrl,
                  focusNode: focus,
                  expands: true,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.center,
                  style: AppTypography.mono12.copyWith(color: fc.text),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: mixed ? 'mixed' : hint,
                    hintStyle: AppTypography.mono12.copyWith(color: fc.muted),
                    filled: true,
                    fillColor: fc.surface2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onSubmitted: (_) =>
                      isFill ? _commitFillHex() : _commitStrokeHex(),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < swatches.length; i += 5)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: swatches.sublist(i, i + 5),
            ),
          ),
      ],
    );
  }

  Widget _sliderBlock(
    FcTokens fc,
    String label,
    double value,
    double min,
    double max,
    int divisions,
    bool mixed,
    double? drag,
    void Function(double?) setDrag,
    SketchStyle Function(SketchStyle, double) apply,
  ) {
    final shown = (drag ?? value).clamp(min, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label(fc, label),
              Text(
                mixed && drag == null ? '—' : shown.toStringAsFixed(1),
                style: AppTypography.mono12.copyWith(color: fc.text),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 24,
          child: Slider(
            value: shown,
            min: min,
            max: max,
            divisions: divisions,
            semanticFormatterCallback: (v) => '$label ${v.toStringAsFixed(1)}',
            onChangeStart: (_) => _ctrl.beginDragSession(),
            onChanged: (v) {
              setState(() => setDrag(v));
              _applyStyle((s) => apply(s, v));
            },
            onChangeEnd: (_) {
              setState(() => setDrag(null));
              _ctrl.endDragSession();
            },
          ),
        ),
      ],
    );
  }

  Widget _dimensionsSection(FcTokens fc, bool editable) {
    return _titled(
      fc,
      'Position & size',
      Column(
        children: [
          Row(
            children: [
              Expanded(child: _numberField(fc, 'X', _xCtrl, _xFocus, editable)),
              const SizedBox(width: 6),
              Expanded(child: _numberField(fc, 'Y', _yCtrl, _yFocus, editable)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _numberField(fc, 'W', _wCtrl, _wFocus, editable)),
              const SizedBox(width: 6),
              Expanded(child: _numberField(fc, 'H', _hCtrl, _hFocus, editable)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numberField(
    FcTokens fc,
    String label,
    TextEditingController ctrl,
    FocusNode focus,
    bool editable,
  ) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: fc.surface2,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Text(
              label,
              style: AppTypography.bodySm.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: fc.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: ValueKey('properties_field_$label'),
              controller: ctrl,
              focusNode: focus,
              enabled: editable,
              style: AppTypography.mono12.copyWith(
                color: editable ? fc.text : fc.muted,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: const InputDecoration.collapsed(hintText: null),
              onSubmitted: (_) => _commitDimensions(),
            ),
          ),
        ],
      ),
    );
  }

  /// 32px surface2 well that hosts a dropdown: the mockup's `<select>`.
  Widget _selectBox<T>(
    FcTokens fc, {
    Key? key,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    Widget? hint,
    Widget? disabledHint,
  }) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: fc.surface2,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: DropdownButton<T>(
        key: key,
        value: value,
        isExpanded: true,
        isDense: true,
        hint: hint,
        disabledHint: disabledHint,
        underline: const SizedBox.shrink(),
        icon: FcIconGlyph(FcIcons.chevronDown, size: 14, color: fc.muted),
        borderRadius: BorderRadius.circular(AppRadius.menu),
        dropdownColor: Color.alphaBlend(fc.glassStrong, fc.bg),
        style: AppTypography.bodyBase.copyWith(fontSize: 13, color: fc.text),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  /// Family and weight of anything that paints a label, or `null` for
  /// elements that carry none.
  static (String?, bool)? _fontOf(SketchElement el) => switch (el) {
    SketchText(:final fontFamily, :final bold) ||
    SketchRectangle(:final fontFamily, :final bold) ||
    SketchEllipse(:final fontFamily, :final bold) ||
    SketchDiamond(:final fontFamily, :final bold) ||
    SketchTriangle(:final fontFamily, :final bold) ||
    SketchSticky(:final fontFamily, :final bold) => (fontFamily, bold),
    _ => null,
  };

  /// Copy of [el] with a new label [family] and/or [bold]; one `update`, so
  /// one undo entry, and the new instance re-measures its own bounds.
  void _setFont(SketchElement el, {String? family, bool? bold}) {
    final f = family ?? _fontOf(el)!.$1;
    _ctrl.update(switch (el) {
      SketchText() => el.copyWith(fontFamily: f, bold: bold),
      SketchRectangle() => el.copyWith(fontFamily: f, bold: bold),
      SketchEllipse() => el.copyWith(fontFamily: f, bold: bold),
      SketchDiamond() => el.copyWith(fontFamily: f, bold: bold),
      SketchTriangle() => el.copyWith(fontFamily: f, bold: bold),
      SketchSticky() => el.copyWith(fontFamily: f, bold: bold),
      _ => el,
    });
  }

  /// Folds the legacy family names ("Inter", "JetBrains Mono") into the
  /// element-level `sans` / `mono`, so one dropdown entry covers both.
  static String _familyKey(String? f) => switch (f) {
    null || 'sans' || AppTypography.interFamily => 'sans',
    'mono' || AppTypography.monoFamily => 'mono',
    final other => other,
  };

  /// Font family + Bold for anything that paints a label, plus Align for
  /// [SketchText]. Elements without a label get the disabled select and the
  /// mockup's "Text only" note.
  Widget _fontSection(FcTokens fc, SketchElement el) {
    final font = _fontOf(el);
    final current = _familyKey(font?.$1);
    // Anything else — an "Arial" from a hand-edited JSON file, say — is
    // listed as-is rather than asserting: `DropdownButton` requires its
    // value to be one of its items, and a panel that throws on a file the
    // app happily painted is the worse of the two.
    final labels = {
      'sans': AppTypography.interFamily,
      'mono': AppTypography.monoFamily,
      if (current != 'sans' && current != 'mono') current: current,
    };
    final rowStyle = AppTypography.bodyBase.copyWith(
      fontSize: 13,
      color: fc.muted,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label(fc, 'Font'),
              if (font == null)
                Text(
                  'Text only',
                  style: AppTypography.bodySm.copyWith(
                    fontSize: 11.5,
                    color: fc.muted,
                  ),
                ),
            ],
          ),
        ),
        _selectBox<String>(
          fc,
          value: current,
          disabledHint: Text(labels[current]!, style: rowStyle),
          items: [
            for (final e in labels.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: font == null
              ? null
              : (v) {
                  if (v != null) _setFont(el, family: v);
                },
        ),
        if (font != null)
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Text('Bold', style: rowStyle),
                const Spacer(),
                FcSwitch(
                  key: const ValueKey('properties_bold'),
                  label: 'Bold',
                  value: font.$2,
                  onChanged: (v) => _setFont(el, bold: v),
                ),
              ],
            ),
          ),
        if (el is SketchText) ...[
          const SizedBox(height: 6),
          _GlyphSegmented<TextAlign>(
            key: const ValueKey('properties_align'),
            height: 32,
            // Legacy `TextAlign.left` / `justify` collapse onto the three
            // buttons; `start` reads as left in this left-to-right app.
            value: el.align == TextAlign.center
                ? TextAlign.center
                : el.align == TextAlign.right || el.align == TextAlign.end
                ? TextAlign.right
                : TextAlign.start,
            items: const [
              _Seg(
                TextAlign.start,
                null,
                FcIcons.textAlignStart,
                16,
                tooltip: 'Align left',
              ),
              _Seg(
                TextAlign.center,
                null,
                FcIcons.textAlignCenter,
                16,
                tooltip: 'Align center',
              ),
              _Seg(
                TextAlign.right,
                null,
                FcIcons.textAlignEnd,
                16,
                tooltip: 'Align right',
              ),
            ],
            onChanged: (v) => _ctrl.update(el.copyWith(align: v)),
          ),
        ],
      ],
    );
  }

  // ── kind-specific sections ─────────────────────────────────────────────

  void _syncShapeFields(SketchElement el, bool fresh) {
    if (el is SketchFrame || el is SketchEntity) {
      final name = el is SketchFrame ? el.name : (el as SketchEntity).name;
      if (fresh || !_nameFocus.hasFocus) _nameCtrl.text = name;
    }
    if (el is SketchEntity && (fresh || !_attrsFocus.hasFocus)) {
      if (fresh) _attrsError = null;
      _attrsCtrl.text = el.attributes
          .map(
            (a) => [
              a.name,
              if (a.type.isNotEmpty) a.type,
              if (a.primaryKey) 'PK',
              if (a.foreignKey) 'FK',
            ].join(' '),
          )
          .join('\n');
    }
  }

  void _commitName() {
    final el = _loaded;
    final name = _nameCtrl.text.trim();
    if (el is SketchFrame && name != el.name) {
      _ctrl.update(el.copyWith(name: name));
    } else if (el is SketchEntity && name != el.name) {
      _ctrl.update(el.copyWith(name: name));
    }
  }

  /// "name type [PK] [FK]" per line, parsed leniently: blank lines vanish,
  /// flags may sit anywhere in any case, and whatever is left after the
  /// first word is the type.
  static List<EntityAttribute> _parseAttributes(String text) {
    final rows = <EntityAttribute>[];
    for (final line in text.split('\n')) {
      final words = line
          .trim()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty);
      final flags = words.map((w) => w.toUpperCase()).toSet();
      final rest = words
          .where((w) => w.toUpperCase() != 'PK' && w.toUpperCase() != 'FK')
          .toList();
      if (rest.isEmpty) continue;
      rows.add(
        EntityAttribute(
          name: rest.first,
          type: rest.skip(1).join(' '),
          primaryKey: flags.contains('PK'),
          foreignKey: flags.contains('FK'),
        ),
      );
    }
    return rows;
  }

  void _commitAttributes() {
    final el = _loaded;
    if (el is! SketchEntity) return;
    final attrs = _parseAttributes(_attrsCtrl.text);
    // Same rule as the MCP/diagram path: names are unique within an entity.
    final dup = attrs.map((a) => a.name).toSet().length != attrs.length;
    if (dup != (_attrsError != null) && mounted) {
      setState(() => _attrsError = dup ? 'Duplicate attribute name' : null);
    }
    if (dup) return;
    final same =
        attrs.length == el.attributes.length &&
        [
          for (var i = 0; i < attrs.length; i++)
            attrs[i].name == el.attributes[i].name &&
                attrs[i].type == el.attributes[i].type &&
                attrs[i].primaryKey == el.attributes[i].primaryKey &&
                attrs[i].foreignKey == el.attributes[i].foreignKey,
        ].every((b) => b);
    if (same) return;
    _ctrl.update(el.copyWith(attributes: attrs).fittedToAttributes());
  }

  Widget _arrowSection(FcTokens fc, SketchArrow el) {
    final rowStyle = AppTypography.bodyBase.copyWith(
      fontSize: 13,
      color: fc.text,
    );
    return _titled(
      fc,
      'Arrow',
      Column(
        children: [
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Text('Elbow', style: rowStyle),
                const Spacer(),
                FcSwitch(
                  key: const ValueKey('properties_elbow'),
                  label: 'Elbow',
                  value: el.elbowed,
                  onChanged: (v) => _ctrl.update(el.copyWith(elbowed: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _headPicker(
            fc,
            'Start',
            const ValueKey('properties_start_head'),
            el.startHead,
            (v) => _ctrl.update(el.copyWith(startHead: v)),
          ),
          const SizedBox(height: 6),
          _headPicker(
            fc,
            'End',
            const ValueKey('properties_end_head'),
            el.endHead,
            (v) => _ctrl.update(el.copyWith(endHead: v)),
          ),
        ],
      ),
    );
  }

  List<Widget> _kindSection(FcTokens fc, SketchElement el) {
    final rowStyle = AppTypography.bodyBase.copyWith(
      fontSize: 13,
      color: fc.muted,
    );
    return switch (el) {
      SketchFrame() => [_titled(fc, 'Frame', _nameField(fc, 'Name'))],
      SketchIcon() => [
        _titled(
          fc,
          'Icon',
          _selectBox<String>(
            fc,
            key: const ValueKey('properties_icon'),
            value: iconCatalog.containsKey(el.name) ? el.name : null,
            hint: Text(el.name, style: rowStyle),
            items: [
              for (final e in iconCatalog.entries)
                DropdownMenuItem(
                  value: e.key,
                  child: Row(
                    children: [
                      Icon(e.value, size: 16, color: fc.text),
                      const SizedBox(width: 8),
                      Text(e.key, style: rowStyle.copyWith(color: fc.text)),
                    ],
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) _ctrl.update(el.copyWith(name: v));
            },
          ),
        ),
      ],
      SketchEntity() => [
        _titled(
          fc,
          'Entity',
          Column(
            children: [
              _nameField(fc, 'Name'),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('properties_attributes'),
                controller: _attrsCtrl,
                focusNode: _attrsFocus,
                minLines: 3,
                maxLines: 8,
                style: AppTypography.mono12.copyWith(color: fc.text),
                decoration: _fieldDecoration(
                  fc,
                  'Attributes — one per line: name type [PK] [FK]',
                ).copyWith(errorText: _attrsError),
              ),
            ],
          ),
        ),
      ],
      _ => const <Widget>[],
    };
  }

  InputDecoration _fieldDecoration(FcTokens fc, String label) =>
      InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: AppTypography.caption.copyWith(color: fc.muted),
        filled: true,
        fillColor: fc.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      );

  Widget _nameField(FcTokens fc, String label) => TextField(
    key: const ValueKey('properties_name'),
    controller: _nameCtrl,
    focusNode: _nameFocus,
    style: AppTypography.bodyBase.copyWith(fontSize: 13, color: fc.text),
    decoration: _fieldDecoration(fc, label),
    onSubmitted: (_) => _commitName(),
  );

  /// Readable names for [ArrowheadStyle]; the ER ones say what they draw.
  static const _headLabels = {
    ArrowheadStyle.none: 'None',
    ArrowheadStyle.arrow: 'Arrow',
    ArrowheadStyle.one: 'One',
    ArrowheadStyle.many: 'Many',
    ArrowheadStyle.zeroOrOne: 'Zero or one',
    ArrowheadStyle.zeroOrMany: 'Zero or many',
    ArrowheadStyle.oneOrMany: 'One or many',
  };

  Widget _headPicker(
    FcTokens fc,
    String label,
    Key key,
    ArrowheadStyle value,
    ValueChanged<ArrowheadStyle> onPick,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            '$label head',
            style: AppTypography.bodyBase.copyWith(
              fontSize: 13,
              color: fc.muted,
            ),
          ),
        ),
        Expanded(
          child: _selectBox<ArrowheadStyle>(
            fc,
            key: key,
            value: value,
            items: [
              for (final e in _headLabels.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) {
              if (v != null) onPick(v);
            },
          ),
        ),
      ],
    );
  }

  /// Ghost "Edit JSON" button under a hairline divider.
  Widget _editJsonButton(FcTokens fc, SketchElement el) {
    return Container(
      // The mockup pulls the divider 2px up into the 14px section gap.
      transform: Matrix4.translationValues(0, -2, 0),
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: fc.glassBorder)),
      ),
      alignment: Alignment.centerLeft,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.button),
          onTap: () => _openJsonDialog(el),
          child: SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FcIconGlyph(FcIcons.code, size: 16, color: fc.muted),
                  const SizedBox(width: 8),
                  Text(
                    'Edit JSON',
                    style: AppTypography.bodyBase.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: fc.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openJsonDialog(SketchElement el) async {
    const encoder = JsonEncoder.withIndent('  ');
    final textCtrl = TextEditingController(text: encoder.convert(el.toJson()));
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              // A 16-line editor plus chrome needs ~450 px; on a shorter
              // window the content scrolls instead of overflowing.
              scrollable: true,
              title: Text(
                'Edit element JSON',
                style: AppTypography.headlineMd.copyWith(
                  fontSize: 16,
                  color: _colorScheme.onSurface,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: textCtrl,
                      maxLines: 16,
                      minLines: 8,
                      style: AppTypography.labelMono.copyWith(
                        fontSize: 12,
                        color: _colorScheme.onSurface,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: _colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    try {
                      final decoded =
                          jsonDecode(textCtrl.text) as Map<String, dynamic>;
                      final updated = SketchElement.fromJson(decoded);
                      if (updated.id != el.id) {
                        setDialogState(() => error = 'id must stay "${el.id}"');
                        return;
                      }
                      _ctrl.update(updated);
                      Navigator.of(dialogContext).pop();
                    } catch (e) {
                      setDialogState(() => error = 'Invalid JSON: $e');
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    textCtrl.dispose();
  }
}

/// A style field the panel displays, used to mark the ones a multi-element
/// selection disagrees about.
enum _MixedField {
  strokeColor,
  fillColor,
  strokeWidth,
  roughness,
  strokeStyle,
  fillStyle,
}

/// One option of a [_GlyphSegmented]: a preview glyph over an optional label.
class _Seg<T> {
  const _Seg(
    this.value,
    this.label,
    this.glyph,
    this.glyphSize, {
    this.tooltip,
  });
  final T value;
  final String? label;
  final FcIcon glyph;
  final double glyphSize;
  final String? tooltip;
}

/// The mockup's segmented control with a glyph over its label (stroke/fill
/// style) or a lone glyph (alignment). [FcSegmented] is text-only, so this is
/// the inspector's own: same surface2 well (padding 3, radius 10, 2px gaps),
/// selected segment raised in accentText with the grid's 0 1 2 .12 shadow.
///
/// [value] `null` = nothing selected (a mixed multi-selection).
/// [autoWidth] sizes segments like CSS `flex: 1 1 auto` (content width plus an
/// equal share of the slack) instead of `flex: 1 1 0` (all equal).
class _GlyphSegmented<T> extends StatelessWidget {
  const _GlyphSegmented({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.height,
    this.gap = 6,
    this.autoWidth = false,
  });

  final T? value;
  final List<_Seg<T>> items;
  final ValueChanged<T> onChanged;
  final double height;
  final double gap;
  final bool autoWidth;

  static TextStyle _text(Color c) =>
      AppTypography.caption.copyWith(letterSpacing: 0, height: 1.2, color: c);

  Widget _segment(FcTokens fc, _Seg<T> s) {
    final selected = s.value == value;
    final color = selected ? fc.accentText : fc.text;
    Widget w = Semantics(
      button: true,
      selected: selected,
      label: s.label ?? s.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(s.value),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? fc.raised : null,
            borderRadius: BorderRadius.circular(AppRadius.input),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FcIconGlyph(s.glyph, size: s.glyphSize, color: color),
              if (s.label != null) ...[
                SizedBox(height: gap),
                Text(
                  s.label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (s.tooltip != null) w = Tooltip(message: s.tooltip!, child: w);
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: fc.surface2,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: autoWidth
          ? LayoutBuilder(
              builder: (context, box) {
                final natural = [
                  for (final s in items)
                    8 +
                        ((TextPainter(
                          text: TextSpan(
                            text: s.label ?? '',
                            style: _text(fc.text),
                          ),
                          textDirection: TextDirection.ltr,
                        )..layout()).width).clamp(s.glyphSize, double.infinity),
                ];
                final avail = box.maxWidth - 2 * (items.length - 1);
                final total = natural.reduce((a, b) => a + b);
                // Wider than the island (a fallback font, say): shrink every
                // segment in proportion instead of overflowing.
                final scale = total > avail ? avail / total : 1.0;
                final extra = total < avail
                    ? (avail - total) / items.length
                    : 0;
                return Row(
                  children: [
                    for (final (i, s) in items.indexed) ...[
                      if (i > 0) const SizedBox(width: 2),
                      SizedBox(
                        width: natural[i] * scale + extra,
                        child: _segment(fc, s),
                      ),
                    ],
                  ],
                );
              },
            )
          : Row(
              children: [
                for (final (i, s) in items.indexed) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(child: _segment(fc, s)),
                ],
              ],
            ),
    );
  }
}
