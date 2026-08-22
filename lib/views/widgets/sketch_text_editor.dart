import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:flowcraft/core/canvas/viewport_transform.dart';
import 'package:flowcraft/core/domain/sticky_bubble_geometry.dart';
import 'package:flowcraft/core/domain/text_metrics.dart';
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

  /// Distance from the edit box's outer edge to its first glyph: the 4/2px
  /// decorative padding below plus the 1px border. The [Positioned] box is
  /// shifted back by this and grown by twice it, so the content box lands on
  /// the element's own geometry — otherwise the text visibly jumps by a few
  /// pixels the instant editing starts, and jumps back on commit.
  static const Offset _editorInset = Offset(5, 3);

  /// Horizontal room a shape's centred label gives up, both sides together,
  /// before it wraps. Mirrors `SketchPainter._labelInset` (the `maxWidth:
  /// bounds.width - 12` in `_drawCenteredText`), which is private to the
  /// painter; a label whose natural width falls inside those 12 px would
  /// otherwise sit on one line here and wrap to two the moment it commits.
  static const double _shapeLabelInset = 12.0;

  /// Width a free text's editor keeps past its widest line, in screen px at
  /// zoom 1: room for the caret and the glyph being typed, so the box never
  /// soft-wraps a line the painter draws unbroken.
  static const double _freeTextSlack = 24.0;

  /// Narrowest editor box, in screen px — a box with nowhere to type is no
  /// use on a 10-px shape or an empty text.
  static const double _minEditorWidth = 60.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    // Free text is sized from its own content (see `_editorBoxFor`), so the
    // box has to be re-laid-out on every keystroke, not only on controller
    // changes.
    _textCtrl.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _sync();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  /// Commits when focus walks away without a key or a click ending the edit
  /// — Tab, most often. Left open, the editor stayed on screen with tool
  /// keys live again and Escape no longer reaching it.
  ///
  /// Harmless on the commit/cancel paths: `_sync` clears `_activeId` before
  /// it unfocuses, so the edit is already over by the time this fires.
  void _onFocusChanged() {
    if (_focusNode.hasFocus) return;
    if (_activeId == null && _activeCanvasPos == null) return;
    _commit();
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
    _focusNode.removeListener(_onFocusChanged);
    _textCtrl.removeListener(_onTextChanged);
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

  /// Screen-space box for the editor's *text content* — where the glyphs go,
  /// not where the decorated edit box goes. [build] grows it by
  /// [_editorInset] to make room for the surrounding chrome, which is what
  /// keeps the glyphs sitting exactly where [SketchPainter] draws them once
  /// the edit is committed.
  ///
  /// `fontFamily` is always the face the painter will actually use —
  /// resolved through [TextMetrics.resolveFontFamily], the same call every
  /// committed label goes through — so the glyphs never reflow on commit.
  ({
    Offset screenPos,
    double width,
    double height,
    double fontSize,
    String fontFamily,
  })? _editorBoxFor(SketchElement? el) {
    final viewport = widget.viewport;
    final zoom = viewport.zoom;

    if (el != null) {
      if (el is SketchSticky) {
        // The same call `SketchPainter._drawStickyLabel` lays the committed
        // label out with. Read from it rather than repeating its insets:
        // the bubble's padding is not a number this file gets to hold a
        // second copy of, or the glyphs shift the moment editing starts and
        // shift back on commit.
        //
        // `rect`, not `bounds` — a note being edited is always expanded (the
        // gesture layer opens one before it hands over), and `rect` is what
        // the bubble is laid out from.
        final box = StickyBubbleGeometry.textBoxOf(el.rect);
        final tl = ViewportTransform.canvasToScreen(box.topLeft, viewport);
        return (
          screenPos: tl,
          width: box.width * zoom,
          height: box.height * zoom,
          fontSize: el.fontSize * zoom,
          fontFamily: TextMetrics.resolveFontFamily(null),
        );
      }
      if (el is SketchRectangle ||
          el is SketchEllipse ||
          el is SketchDiamond ||
          el is SketchTriangle) {
        // The painter wraps a centred label inside `bounds` less
        // `_shapeLabelInset`; wrapping here at the full width would give a
        // label in that 12-px band one line count while editing and another
        // once committed.
        final bounds = el.bounds;
        final tl = ViewportTransform.canvasToScreen(
          Offset(bounds.left + _shapeLabelInset / 2, bounds.top),
          viewport,
        );
        return (
          screenPos: tl,
          width: (bounds.width - _shapeLabelInset) * zoom,
          height: bounds.height * zoom,
          fontSize: _shapeFontSize(el) * zoom,
          fontFamily: TextMetrics.resolveFontFamily(null),
        );
      }
      if (el is SketchText) {
        final tl = ViewportTransform.canvasToScreen(el.position, viewport);
        final fontFamily = TextMetrics.resolveFontFamily(el.fontFamily);
        return (
          screenPos: tl,
          width: _freeTextWidth(el.fontSize, fontFamily),
          height: el.fontSize * 2 * zoom,
          fontSize: el.fontSize * zoom,
          fontFamily: fontFamily,
        );
      }
    }
    if (_activeCanvasPos != null) {
      final tl = ViewportTransform.canvasToScreen(_activeCanvasPos!, viewport);
      // Matches `SketchText.create`'s defaults, which are what
      // `commitTextEdit` builds from this pending position.
      final fontFamily = TextMetrics.resolveFontFamily(null);
      return (
        screenPos: tl,
        width: _freeTextWidth(16, fontFamily),
        height: 40 * zoom,
        fontSize: 16 * zoom,
        fontFamily: fontFamily,
      );
    }
    return null;
  }

  /// Editor width for a free [SketchText]: its widest line as the painter
  /// lays it out (unbounded — free text never wraps), scaled to the screen,
  /// plus [_freeTextSlack]. A fixed 300 px used to soft-wrap anything longer
  /// inside the editor, so the glyphs jumped back onto one line on commit.
  ///
  /// Measured from the *live* text (not the element's), since the box has
  /// to keep up with what is being typed.
  double _freeTextWidth(double fontSize, String fontFamily) {
    final zoom = widget.viewport.zoom;
    final measured = TextMetrics.measure(
      text: _textCtrl.text,
      fontSize: fontSize,
      fontFamily: fontFamily,
    );
    return measured.width * zoom + _freeTextSlack;
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
    // Mid-composition (CJK, pinyin, dead keys) Enter confirms the candidate
    // and Escape drops it. On macOS the framework sees the hardware key
    // before the IME does, so acting here would commit the whole element —
    // or throw the edit away — on a keystroke meant for the composer.
    if (_textCtrl.value.composing.isValid) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _cancel();
      return true;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
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
    //
    // A sticky is the exception the painter also makes: its stroke colour is
    // its paper colour, so its glyphs take `inkColor` instead.
    if (el is SketchSticky) return el.inkColor;
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

    // A sticky is already a filled bubble on the canvas underneath — the
    // painter keeps drawing it while only its text is suppressed — so the
    // editor's own tinted box and border would be a grey rectangle sitting
    // inside it. The bubble *is* the composer, which is the point of the
    // chat-bubble shape; the chrome is dropped rather than doubled.
    final onBubble = el is SketchSticky;

    final textColor = _resolveTextColor(el);

    final editorHeight = box.height.clamp(20, 4000) + _editorInset.dy * 2;

    // Open-ended composers grow with their lines; only a shape keeps a
    // fixed box, which is what keeps its centred label centred. A note
    // grows to fit its text on commit and free text is painted line for
    // line, so for both the editor has to grow *while typing* or the third
    // line scrolls out of sight inside a box sized for two.
    final growsWithText = !isShape;

    return Positioned(
      left: box.screenPos.dx - _editorInset.dx,
      top: box.screenPos.dy - _editorInset.dy,
      width: box.width.clamp(_minEditorWidth, 4000) + _editorInset.dx * 2,
      height: growsWithText ? null : editorHeight,
      child: Focus(
        onKeyEvent: (_, e) =>
            _onKey(e) ? KeyEventResult.handled : KeyEventResult.ignored,
        child: TapRegion(
          onTapOutside: (_) => _commit(),
          child: Container(
            alignment: isShape ? Alignment.center : Alignment.topLeft,
            constraints: growsWithText
                ? BoxConstraints(minHeight: editorHeight)
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              // ~6% black tint — a decorative edit-box background, not a
              // design-system chrome color, hence `Color.fromRGBO` rather
              // than an `AppColors` token.
              color: onBubble
                  ? const Color(0x00000000)
                  : const Color.fromRGBO(0, 0, 0, 0.0627),
              border: Border.all(
                // Kept at width 1 even when invisible: `_editorInset`
                // accounts for a 1px border, so dropping the border outright
                // would move every glyph a pixel and reintroduce the jump
                // this inset exists to prevent.
                color: onBubble
                    ? const Color(0x00000000)
                    : widget.cursorColor.withValues(alpha: 0.6),
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
                fontFamily: box.fontFamily,
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
