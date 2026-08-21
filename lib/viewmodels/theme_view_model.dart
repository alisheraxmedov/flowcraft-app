import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app is in dark mode. `true` = dark.
class ThemeViewModel extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final themeViewModelProvider = NotifierProvider<ThemeViewModel, bool>(
  ThemeViewModel.new,
);
