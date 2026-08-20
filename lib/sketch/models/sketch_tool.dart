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
  eraser;

  /// Whether this tool creates new elements when the user drags.
  bool get isCreator =>
      this != SketchTool.select &&
      this != SketchTool.hand &&
      this != SketchTool.eraser;

  /// Whether this tool primarily uses pointer-down + drag to create a
  /// bounded shape (rect/ellipse/diamond/triangle/line/arrow/sticky).
  bool get isBounded =>
      this == SketchTool.rectangle ||
      this == SketchTool.ellipse ||
      this == SketchTool.diamond ||
      this == SketchTool.triangle ||
      this == SketchTool.line ||
      this == SketchTool.arrow ||
      this == SketchTool.sticky;
}
