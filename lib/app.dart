import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flowcraft/core/theme/app_theme.dart';
import 'package:flowcraft/viewmodels/theme_view_model.dart';
import 'package:flowcraft/views/splash_view.dart';

/// App root: hosts [MaterialApp] and reacts to [themeViewModelProvider].
/// All other state (sketch canvas, MCP toggle) lives in `WhiteboardView`
/// and its view models — reached via [SplashView] once startup finishes.
class FlowCraftWhiteboardApp extends ConsumerWidget {
  const FlowCraftWhiteboardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeViewModelProvider);

    return MaterialApp(
      // `FlowCraft`, matching the native window titles on every platform —
      // on Linux the GTK embedder puts this string in the Alt-Tab switcher
      // beside the header bar's own title.
      title: 'FlowCraft',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const SplashView(),
    );
  }
}
