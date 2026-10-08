import 'package:flutter/widgets.dart' show IconData;
import 'package:material_symbols_icons/symbols.dart';

/// Icons a [SketchIcon] can show, by the short names files and MCP use.
///
/// Const `Symbols.*` references (not looked up by code point at runtime) so
/// the icon tree-shaker keeps exactly these glyphs.
const Map<String, IconData> iconCatalog = {
  'database': Symbols.database,
  'server': Symbols.dns,
  'cloud': Symbols.cloud,
  'user': Symbols.person,
  'queue': Symbols.stacks,
  'lock': Symbols.lock,
  'api': Symbols.api,
  'storage': Symbols.hard_drive,
  'cache': Symbols.memory,
  'function': Symbols.function,
  'web': Symbols.language,
  'mobile': Symbols.smartphone,
  'mail': Symbols.mail,
  'schedule': Symbols.schedule,
  'warning': Symbols.warning,
  'key': Symbols.key,
  'file': Symbols.description,
  'folder': Symbols.folder,
  'globe': Symbols.public,
  'gear': Symbols.settings,
  'bug': Symbols.bug_report,
  'chart': Symbols.bar_chart,
  'robot': Symbols.smart_toy,
  'terminal': Symbols.terminal,
};

/// Glyph for [name]; an unknown name shows a help mark rather than nothing.
IconData iconFor(String name) => iconCatalog[name] ?? Symbols.help;
