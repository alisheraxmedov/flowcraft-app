import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:flowcraft/core/canvas/viewport_transform.dart';
import 'package:flowcraft/core/theme/app_colors.dart';
import 'package:flowcraft/models/flow_viewport.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

/// Inline text editor overlaid on the canvas while
/// [SketchController.editingElementId] (or [editingCanvasPosition]) is set.
///
/// Uses [EditableText] so the package stays free of Material / Cupertino
/// imports. Submits the typed text on Enter (or focus loss) and cancels
/// on Escape.
class SketchTextEditor extends StatefulWidget {
  const SketchTextEditor({
    super.key,
    required this.controller,
    required this.viewport,
    // Downstream of the user's own sketch style, not chrome — mirrors
    // `SketchStyle`'s / the toolbar palette's default stroke color;
    // [SketchLayer] always overrides this with the live
    // `currentStyle.strokeColor` in practice (see `_resolveTextColor`).
    this.textColor = const Color(0xFF1E1E1E),
    this.cursorColor = AppColors.primary,
  });

  final SketchController controller;
  final FlowViewport viewport;
  final Color textColor;
  final Color cursorColor;

  @override
  State<SketchTextEditor> createState() => _SketchTextEditorState();
}

class _SketchTextEditorState extends State<SketchTextEditor> {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _activeId;
  Offset? _activeCanvasPos;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(SketchTextEditor old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _focusNode.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _sync() {
    final id = widget.controller.editingElementId;
    final pos = widget.controller.editingCanvasPosition;

    // Detect a transition from inactive → active.
    if ((id != null || pos != null) &&
        (_activeId != id || _activeCanvasPos != pos)) {
      _activeId = id;
      _activeCanvasPos = pos;

      String initial = '';
      if (id != null) {
        final el = _findById(id);
        initial = _extractText(el) ?? '';
      }
      _textCtrl.text = initial;
      _textCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: initial.length,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }

    // Transition active → inactive.
    if (id == null && pos == null && (_activeId != null || _activeCanvasPos != null)) {
      _activeId = null;
      _activeCanvasPos = null;
      _focusNode.unfocus();
    }

    if (mounted) setState(() {});
  }

  SketchElement? _findById(String id) {
    for (final e in widget.controller.elements) {
      if (e.id == id) return e;
    }
    return null;
  }

  String? _extractText(SketchElement? el) {
    if (el == null) return null;
    if (el is SketchRectangle) return el.text;
    if (el is SketchEllipse) return el.text;
    if (el is SketchDiamond) return el.text;
    if (el is SketchTriangle) return el.text;
    if (el is SketchSticky) return el.text;
    if (el is SketchText) return el.text;
    return null;
  }

  double _shapeFontSize(SketchElement el) {
    if (el is SketchRectangle) return el.fontSize;
    if (el is SketchEllipse) return el.fontSize;
    if (el is SketchDiamond) return el.fontSize;
    if (el is SketchTriangle) return el.fontSize;
    if (el is SketchSticky) return el.fontSize;
    return 16.0;
  }

  ({Offset screenPos, double width, double height, double fontSize})?
      _editorBoxFor(SketchElement? el) {
    final viewport = widget.viewport;
    final zoom = viewport.zoom;

    if (el != null) {
      if (el is SketchRectangle ||
          el is SketchEllipse ||
          el is SketchDiamond ||
          el is SketchTriangle ||
          el is SketchSticky) {
        final bounds = el.bounds;
        final tl = ViewportTransform.canvasToScreen(bounds.topLeft, viewport);
        final fontSize = _shapeFontSize(el);
        return (
          screenPos: tl,
          width: bounds.width * zoom,
          height: bounds.height * zoom,
          fontSize: fontSize * zoom,
        );
      }
      if (el is SketchText) {
        final tl = ViewportTransform.canvasToScreen(el.position, viewport);
        return (
          screenPos: tl,
          width: 300,
          height: el.fontSize * 2 * zoom,
          fontSize: el.fontSize * zoom,
        );
      }
    }
    if (_activeCanvasPos != null) {
      final tl = ViewportTransform.canvasToScreen(_activeCanvasPos!, viewport);
      return (
        screenPos: tl,
        width: 300,
        height: 40 * zoom,
        fontSize: 16 * zoom,
      );
    }
    return null;
  }

  void _commit() {
    if (_activeId == null && _activeCanvasPos == null) return;
    widget.controller.commitTextEdit(_textCtrl.text);
  }

  void _cancel() {
    if (_activeId == null && _activeCanvasPos == null) return;
    widget.controller.cancelTextEdit();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancel();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _commit();
      return true;
    }
    return false;
  }

  Color _resolveTextColor(SketchElement? el) {
    // Text drawn inside a shape (or as standalone text) inherits the
    // element's own stroke colour — that's also what the painter uses
    // when rendering the committed text, so the editor preview matches.
    if (el != null) return el.style.strokeColor;
    return widget.textColor;
  }

  @override
  Widget build(BuildContext context) {
    final id = _activeId;
    final el = id == null ? null : _findById(id);
    if (id == null && _activeCanvasPos == null) {
      return const SizedBox.shrink();
    }

    final box = _editorBoxFor(el);
    if (box == null) return const SizedBox.shrink();

    final isShape = el is SketchRectangle ||
        el is SketchEllipse ||
        el is SketchDiamond ||
        el is SketchTriangle;

    final textColor = _resolveTextColor(el);

    return Positioned(
      left: box.screenPos.dx,
      top: box.screenPos.dy,
      width: box.width.clamp(60, 4000),
      height: box.height.clamp(20, 4000),
      child: Focus(
        onKeyEvent: (_, e) =>
            _onKey(e) ? KeyEventResult.handled : KeyEventResult.ignored,
        child: TapRegion(
          onTapOutside: (_) => _commit(),
          child: Container(
            alignment: isShape ? Alignment.center : Alignment.topLeft,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              // ~6% black tint — a decorative edit-box background, not a
              // design-system chrome color, hence `Color.fromRGBO` rather
              // than an `AppColors` token.
              color: const Color.fromRGBO(0, 0, 0, 0.0627),
              border: Border.all(
                color: widget.cursorColor.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: EditableText(
              controller: _textCtrl,
              focusNode: _focusNode,
              maxLines: null,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: TextStyle(
                color: textColor,
                fontSize: box.fontSize.clamp(8.0, 200.0),
              ),
              cursorColor: widget.cursorColor,
              backgroundCursorColor: widget.cursorColor.withValues(alpha: 0.4),
              textAlign: isShape ? TextAlign.center : TextAlign.start,
              cursorWidth: 1.5,
              showCursor: true,
              autofocus: true,
            ),
          ),
        ),
      ),
    );
  }
}
