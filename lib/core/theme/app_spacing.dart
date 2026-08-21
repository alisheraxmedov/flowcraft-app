/// "Kinetic Blueprint" spacing tokens — single source of truth for layout
/// constants used across the app chrome (bars, panels, canvas grid).
class AppSpacing {
  AppSpacing._();

  /// Spacing between primary canvas grid dots.
  static const double canvasGrid = 24.0;

  /// Spacing between finer canvas sub-grid marks.
  static const double canvasSubgrid = 8.0;

  /// Inner padding for floating panels/cards.
  static const double panelPadding = 16.0;

  /// Gap between adjacent controls inside a toolbar/tool rail.
  static const double toolbarGap = 8.0;

  /// Outer margin between floating chrome and the window edge.
  static const double gutter = 24.0;
}
