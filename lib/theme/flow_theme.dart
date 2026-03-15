import 'dart:ui';

/// Full theme configuration for FlowCraft.
///
/// Controls the visual appearance of the canvas, nodes, edges,
/// handles, grid, and overlays.
class FlowTheme {
  /// Creates a [FlowTheme].
  const FlowTheme({
    required this.canvasColor,
    required this.gridColor,
    required this.nodeBackgroundColor,
    required this.nodeBorderColor,
    required this.nodeSelectedBorderColor,
    required this.nodeTextColor,
    required this.headerBackgroundColor,
    required this.edgeColor,
    required this.edgeSelectedColor,
    required this.handleColor,
    required this.handleBorderColor,
    required this.selectionBoxColor,
    required this.selectionBoxBorderColor,
    required this.minimapBackgroundColor,
    required this.minimapNodeColor,
    required this.minimapViewportColor,
    this.nodeFontSize = 12.0,
    this.nodeHeaderFontSize = 12.0,
    this.edgeThickness = 2.0,
    this.handleSize = 10.0,
    this.nodeBorderRadius = 8.0,
  });

  // Canvas
  final Color canvasColor;
  final Color gridColor;

  // Nodes
  final Color nodeBackgroundColor;
  final Color nodeBorderColor;
  final Color nodeSelectedBorderColor;
  final Color nodeTextColor;
  final Color headerBackgroundColor;
  final double nodeFontSize;
  final double nodeHeaderFontSize;
  final double nodeBorderRadius;

  // Edges
  final Color edgeColor;
  final Color edgeSelectedColor;
  final double edgeThickness;

  // Handles
  final Color handleColor;
  final Color handleBorderColor;
  final double handleSize;

  // Selection
  final Color selectionBoxColor;
  final Color selectionBoxBorderColor;

  // Minimap
  final Color minimapBackgroundColor;
  final Color minimapNodeColor;
  final Color minimapViewportColor;

  /// Built-in light theme.
  factory FlowTheme.light() {
    return const FlowTheme(
      canvasColor: Color(0xFFFAFAFA),
      gridColor: Color(0x22888888),
      nodeBackgroundColor: Color(0xFFFFFFFF),
      nodeBorderColor: Color(0xFFE0E0E0),
      nodeSelectedBorderColor: Color(0xFF2196F3),
      nodeTextColor: Color(0xFF333333),
      headerBackgroundColor: Color(0xFFF5F5F5),
      edgeColor: Color(0xFF555555),
      edgeSelectedColor: Color(0xFF2196F3),
      handleColor: Color(0xFFFFFFFF),
      handleBorderColor: Color(0xFF2196F3),
      selectionBoxColor: Color(0x222196F3),
      selectionBoxBorderColor: Color(0xFF2196F3),
      minimapBackgroundColor: Color(0xFFF5F5F5),
      minimapNodeColor: Color(0xFF90CAF9),
      minimapViewportColor: Color(0x442196F3),
    );
  }

  /// Built-in dark theme.
  factory FlowTheme.dark() {
    return const FlowTheme(
      canvasColor: Color(0xFF1E1E1E),
      gridColor: Color(0x22FFFFFF),
      nodeBackgroundColor: Color(0xFF2D2D2D),
      nodeBorderColor: Color(0xFF444444),
      nodeSelectedBorderColor: Color(0xFF64B5F6),
      nodeTextColor: Color(0xFFE0E0E0),
      headerBackgroundColor: Color(0xFF363636),
      edgeColor: Color(0xFFAAAAAA),
      edgeSelectedColor: Color(0xFF64B5F6),
      handleColor: Color(0xFF2D2D2D),
      handleBorderColor: Color(0xFF64B5F6),
      selectionBoxColor: Color(0x2264B5F6),
      selectionBoxBorderColor: Color(0xFF64B5F6),
      minimapBackgroundColor: Color(0xFF252525),
      minimapNodeColor: Color(0xFF42A5F5),
      minimapViewportColor: Color(0x4464B5F6),
    );
  }

  /// Creates a copy of this theme with the given fields replaced.
  FlowTheme copyWith({
    Color? canvasColor,
    Color? gridColor,
    Color? nodeBackgroundColor,
    Color? nodeBorderColor,
    Color? nodeSelectedBorderColor,
    Color? nodeTextColor,
    Color? headerBackgroundColor,
    Color? edgeColor,
    Color? edgeSelectedColor,
    Color? handleColor,
    Color? handleBorderColor,
    Color? selectionBoxColor,
    Color? selectionBoxBorderColor,
    Color? minimapBackgroundColor,
    Color? minimapNodeColor,
    Color? minimapViewportColor,
    double? nodeFontSize,
    double? nodeHeaderFontSize,
    double? edgeThickness,
    double? handleSize,
    double? nodeBorderRadius,
  }) {
    return FlowTheme(
      canvasColor: canvasColor ?? this.canvasColor,
      gridColor: gridColor ?? this.gridColor,
      nodeBackgroundColor: nodeBackgroundColor ?? this.nodeBackgroundColor,
      nodeBorderColor: nodeBorderColor ?? this.nodeBorderColor,
      nodeSelectedBorderColor:
          nodeSelectedBorderColor ?? this.nodeSelectedBorderColor,
      nodeTextColor: nodeTextColor ?? this.nodeTextColor,
      headerBackgroundColor:
          headerBackgroundColor ?? this.headerBackgroundColor,
      edgeColor: edgeColor ?? this.edgeColor,
      edgeSelectedColor: edgeSelectedColor ?? this.edgeSelectedColor,
      handleColor: handleColor ?? this.handleColor,
      handleBorderColor: handleBorderColor ?? this.handleBorderColor,
      selectionBoxColor: selectionBoxColor ?? this.selectionBoxColor,
      selectionBoxBorderColor:
          selectionBoxBorderColor ?? this.selectionBoxBorderColor,
      minimapBackgroundColor:
          minimapBackgroundColor ?? this.minimapBackgroundColor,
      minimapNodeColor: minimapNodeColor ?? this.minimapNodeColor,
      minimapViewportColor:
          minimapViewportColor ?? this.minimapViewportColor,
      nodeFontSize: nodeFontSize ?? this.nodeFontSize,
      nodeHeaderFontSize: nodeHeaderFontSize ?? this.nodeHeaderFontSize,
      edgeThickness: edgeThickness ?? this.edgeThickness,
      handleSize: handleSize ?? this.handleSize,
      nodeBorderRadius: nodeBorderRadius ?? this.nodeBorderRadius,
    );
  }
}
