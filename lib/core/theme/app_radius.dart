import 'package:flutter/painting.dart' show BorderRadius, Radius;

/// "Kinetic Blueprint" corner-radius tokens — single source of truth for
/// border radii used across the app chrome.
class AppRadius {
  AppRadius._();

  /// Header icon buttons.
  static const double xs = 4.0;

  /// Input fields / small chips.
  static const double sm = 6.0;

  /// Toolbar buttons, floating panels/cards.
  static const double md = 8.0;

  /// Outer tool-rail container only. Despite the name this is NOT a true
  /// circle/stadium shape in the source design — just a larger corner
  /// radius on a narrow vertical bar.
  static const double full = 12.0;

  /// Glass Canvas radii.
  static const double island = 18.0;
  static const double pill = 999.0;
  static const double menu = 14.0;
  static const double row = 12.0;
  static const double button = 10.0;
  static const double input = 8.0;

  static const BorderRadius xsRadius = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius fullRadius = BorderRadius.all(
    Radius.circular(full),
  );
}
