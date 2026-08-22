import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

/// Floating "Properties" card showing/editing the single currently
/// selected sketch element. Renders nothing when selection is empty or
/// spans more than one element.
///
/// Self-contained like [SketchToolbarRich] / [WhiteboardCanvas]: listens
/// to [controller] directly via `addListener` rather than through Riverpod,
/// so it can be dropped into any `Stack` without extra plumbing.
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
    for (final c in [_xCtrl, _yCtrl, _wCtrl, _hCtrl, _strokeHexCtrl, _fillHexCtrl]) {
      c.dispose();
    }
    for (final f in [_xFocus, _yFocus, _wFocus, _hFocus, _strokeHexFocus, _fillHexFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
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

  void _syncDimensionFields(SketchElement el) {
    final rect = PropertiesPanel.rectOf(el) ?? el.bounds;
    if (!_xFocus.hasFocus) _xCtrl.text = rect.left.toStringAsFixed(0);
    if (!_yFocus.hasFocus) _yCtrl.text = rect.top.toStringAsFixed(0);
    if (!_wFocus.hasFocus) _wCtrl.text = rect.width.toStringAsFixed(0);
    if (!_hFocus.hasFocus) _hCtrl.text = rect.height.toStringAsFixed(0);
  }

  void _onDimensionFocusChange() {
    final anyFocused = [_xFocus, _yFocus, _wFocus, _hFocus].any(
      (f) => f.hasFocus,
    );
    if (!anyFocused) _commitDimensions();
  }

  void _commitDimensions() {
    final el = _selected;
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

  void _syncAppearanceFields(SketchElement el) {
    final style = el.style;
    if (!_strokeHexFocus.hasFocus) {
      _strokeHexCtrl.text = _colorToHex(style.strokeColor);
    }
    if (!_fillHexFocus.hasFocus) {
      _fillHexCtrl.text =
          style.fillColor == null ? '' : _colorToHex(style.fillColor!);
    }
  }

  void _commitStrokeHex() {
    final el = _selected;
    if (el == null) return;
    final color = _hexToColor(_strokeHexCtrl.text);
    if (color == null || color == el.style.strokeColor) return;
    _ctrl.update(el.copyWithStyle(el.style.copyWith(strokeColor: color)));
  }

  void _commitFillHex() {
    final el = _selected;
    if (el == null) return;
    final text = _fillHexCtrl.text.trim();
    // Same `withFillColor` rule the toolbar's fill palette uses, so a fill
    // set from here is just as visible as one set from there: a colour
    // promotes `FillStyle.none` to solid, an empty field clears both.
    final color = text.isEmpty ? null : _hexToColor(text);
    if (color == null && text.isNotEmpty) return;
    final style = el.style.withFillColor(color);
    if (style == el.style) return;
    _ctrl.update(el.copyWithStyle(style));
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _colorScheme = Theme.of(context).colorScheme;

    final el = _selected;
    if (el == null) return const SizedBox.shrink();

    _syncDimensionFields(el);
    _syncAppearanceFields(el);

    final isBounded = PropertiesPanel.rectOf(el) != null;

    return Container(
      width: 280,
      constraints: const BoxConstraints(maxHeight: 640),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: _colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          color: _colorScheme.surfaceContainer.withValues(alpha: 0.95),
          padding: const EdgeInsets.all(AppSpacing.panelPadding),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: 16),
                _dimensionsSection(el, isBounded),
                const SizedBox(height: 16),
                _appearanceSection(el),
                const SizedBox(height: 16),
                _typographySection(el),
                const SizedBox(height: 16),
                _editJsonButton(el),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Text(
          'PROPERTIES',
          style: AppTypography.labelMono.copyWith(
            color: _colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Tooltip(
          message: 'Close',
          child: InkWell(
            borderRadius: AppRadius.xsRadius,
            onTap: _ctrl.clearSelection,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: _colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(color: _colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _dimensionsSection(SketchElement el, bool editable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('DIMENSIONS & POSITION'),
        Row(
          children: [
            Expanded(child: _numberField('X', _xCtrl, _xFocus, editable)),
            const SizedBox(width: 8),
            Expanded(child: _numberField('Y', _yCtrl, _yFocus, editable)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _numberField('W', _wCtrl, _wFocus, editable)),
            const SizedBox(width: 8),
            Expanded(child: _numberField('H', _hCtrl, _hFocus, editable)),
          ],
        ),
      ],
    );
  }

  Widget _numberField(
    String label,
    TextEditingController ctrl,
    FocusNode focus,
    bool editable,
  ) {
    return TextField(
      key: ValueKey('properties_field_$label'),
      controller: ctrl,
      focusNode: focus,
      enabled: editable,
      style: AppTypography.labelMono.copyWith(
        fontSize: 12,
        color: _colorScheme.onSurface,
      ),
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: AppTypography.caption.copyWith(color: _colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: _colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: AppRadius.smRadius,
          borderSide: BorderSide(color: _colorScheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      onSubmitted: (_) => _commitDimensions(),
    );
  }

  Widget _appearanceSection(SketchElement el) {
    final style = el.style;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('APPEARANCE'),
        _colorRow('Fill', style.fillColor, _fillHexCtrl, _fillHexFocus,
            allowNone: true),
        const SizedBox(height: 8),
        _colorRow('Stroke', style.strokeColor, _strokeHexCtrl, _strokeHexFocus),
        const SizedBox(height: 8),
        _strokeWidthDropdown(el, style),
      ],
    );
  }

  Widget _colorRow(
    String label,
    Color? color,
    TextEditingController ctrl,
    FocusNode focus, {
    bool allowNone = false,
  }) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color ?? Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: _colorScheme.outline),
          ),
          child: color == null
              ? Icon(
                  Icons.do_not_disturb_alt,
                  size: 12,
                  color: _colorScheme.onSurfaceVariant,
                )
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.bodyBase.copyWith(
            fontSize: 12,
            color: _colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 96,
          child: TextField(
            key: ValueKey('properties_hex_$label'),
            controller: ctrl,
            focusNode: focus,
            style: AppTypography.labelMono.copyWith(
              fontSize: 12,
              color: _colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: allowNone ? 'none' : '#RRGGBB',
              hintStyle: AppTypography.caption.copyWith(color: _colorScheme.onSurfaceVariant),
              filled: true,
              fillColor: _colorScheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: AppRadius.smRadius,
                borderSide: BorderSide(color: _colorScheme.outlineVariant),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            onSubmitted: (_) =>
                allowNone ? _commitFillHex() : _commitStrokeHex(),
          ),
        ),
      ],
    );
  }

  Widget _strokeWidthDropdown(SketchElement el, SketchStyle style) {
    const presets = [1.0, 2.0, 4.0, 6.0, 8.0];
    final options = {...presets, style.strokeWidth}.toList()..sort();
    return Row(
      children: [
        Text(
          'Stroke width',
          style: AppTypography.bodyBase.copyWith(
            fontSize: 12,
            color: _colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        DropdownButton<double>(
          value: style.strokeWidth,
          dropdownColor: _colorScheme.surfaceContainerHigh,
          underline: const SizedBox.shrink(),
          style: AppTypography.labelMono.copyWith(
            fontSize: 12,
            color: _colorScheme.onSurface,
          ),
          items: [
            for (final w in options)
              DropdownMenuItem(value: w, child: Text('${w.toStringAsFixed(0)}px')),
          ],
          onChanged: (v) {
            if (v == null) return;
            _ctrl.update(el.copyWithStyle(style.copyWith(strokeWidth: v)));
          },
        ),
      ],
    );
  }

  Widget _typographySection(SketchElement el) {
    final isText = el is SketchText;
    final current = isText ? (el.fontFamily ?? 'Inter') : 'Inter';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('TYPOGRAPHY'),
        DropdownButton<String>(
          value: current,
          isExpanded: true,
          dropdownColor: _colorScheme.surfaceContainerHigh,
          underline: const SizedBox.shrink(),
          disabledHint: Text(
            current,
            style: AppTypography.bodyBase.copyWith(
              fontSize: 12,
              color: _colorScheme.onSurfaceVariant,
            ),
          ),
          style: AppTypography.bodyBase.copyWith(
            fontSize: 12,
            color: _colorScheme.onSurface,
          ),
          items: const [
            DropdownMenuItem(value: 'Inter', child: Text('Inter')),
            DropdownMenuItem(
              value: 'JetBrains Mono',
              child: Text('JetBrains Mono'),
            ),
          ],
          onChanged: !isText
              ? null
              : (v) {
                  if (v == null) return;
                  _ctrl.update(el.copyWith(fontFamily: v));
                },
        ),
      ],
    );
  }

  Widget _editJsonButton(SketchElement el) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _openJsonDialog(el),
        icon: const Icon(Icons.code_rounded, size: 16),
        label: const Text('Edit JSON'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _colorScheme.onSurfaceVariant,
          side: BorderSide(color: _colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
          textStyle: AppTypography.bodyBase.copyWith(fontSize: 12),
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
              backgroundColor: _colorScheme.surfaceContainerHigh,
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
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          error!,
                          style: TextStyle(color: _colorScheme.error, fontSize: 12),
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
                        setDialogState(
                          () => error = 'id must stay "${el.id}"',
                        );
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
