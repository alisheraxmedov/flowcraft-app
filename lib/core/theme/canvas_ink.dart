import 'package:flutter/material.dart';

import 'fc_tokens.dart';

/// `SketchStyle`'s own default stroke: near-black, legible on the light
/// canvas and all but invisible on the dark theme's surface.
const Color lightInk = Color(0xFF1E1E1E);

/// The stroke colour a fresh element should be drawn in under [brightness]:
/// the model's own default on light, the theme's ink on dark.
Color inkFor(Brightness brightness) =>
    brightness == Brightness.dark ? FcTokens.dark.ink : lightInk;
