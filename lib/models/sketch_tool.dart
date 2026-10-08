/// Active drawing tool on the canvas.
///
/// Controls how pointer events are interpreted: [select] for picking/moving
/// existing elements; shape tools create the corresponding [SketchElement];
/// [eraser] removes elements; [hand] pans the viewport.
enum SketchTool {
  select,
  hand,
  rectangle,
  ellipse,
  diamond,
  triangle,
  line,
  arrow,
  freedraw,
  text,
  sticky,
  frame,
  icon,
  eraser;

  /// Whether this tool primarily uses pointer-down + drag to create a
  /// bounded shape (rect/ellipse/diamond/triangle/line/arrow/sticky/frame). [icon] is
  /// click-to-place, so it is not bounded.
  bool get isBounded =>
      this == SketchTool.rectangle ||
      this == SketchTool.ellipse ||
      this == SketchTool.diamond ||
      this == SketchTool.triangle ||
      this == SketchTool.line ||
      this == SketchTool.arrow ||
      this == SketchTool.sticky ||
      this == SketchTool.frame;
}
