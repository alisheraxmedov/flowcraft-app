import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/viewmodels/mcp_view_model.dart';
import 'package:flowcraft/viewmodels/projects_view_model.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';
import 'package:flowcraft/views/whiteboard_view.dart';

/// Fixed cyan the logo's own neon glow is rendered in. Deliberately NOT a
/// [ColorScheme] token — the glow is derived from the fixed artwork in
/// `assets/logo/my-logo.png`, so it stays the same cyan regardless of the
/// light/dark toggle, unlike the rest of this screen's chrome.
const Color _logoGlowCyan = Color(0xFF67E8F9);

/// App startup splash: shows the FlowCraft logo with an entrance animation
/// while real startup work (spinning up the MCP control server, restoring
/// the last open project) happens in the background, then swaps itself for
/// [WhiteboardView] once both the work and a minimum display duration are
/// done.
///
/// Deliberately swaps its own build output rather than `Navigator.push`ing
/// to the whiteboard — this screen never needs a stack entry of its own.
class SplashView extends ConsumerStatefulWidget {
  const SplashView({
    super.key,
    this.minDisplayDuration = const Duration(milliseconds: 1300),
    this.readyTimeout = const Duration(seconds: 4),
  });

  /// Floor on how long the splash stays visible, so it never flashes for
  /// a handful of milliseconds on a fast machine — long enough to actually
  /// see the entrance animation play out.
  final Duration minDisplayDuration;

  /// Safety-net ceiling: if real startup work hasn't finished by this
  /// point, proceed to the whiteboard anyway. A slow control server or an
  /// unreadable project directory must never trap the user on the splash
  /// screen.
  final Duration readyTimeout;

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);

    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    // `read`, not `watch` — triggers the providers' eager startup work once;
    // this widget doesn't need to rebuild off their state changes. Reading
    // `sketchControllerProvider` first ensures it exists before the MCP
    // notifier reads it during its own `build()`.
    ref.read(sketchControllerProvider);
    final mcp = ref.read(mcpViewModelProvider.notifier);
    final projects = ref.read(projectsViewModelProvider.notifier);

    final startupWork = Future.wait<void>([
      mcp.ready,
      // Restoring the last project mutates the canvas, so the whiteboard
      // must not appear before it lands — otherwise the user watches an
      // empty canvas pop into their saved scene a beat later.
      projects.ready,
      Future<void>.delayed(widget.minDisplayDuration),
    ]);

    try {
      await startupWork.timeout(widget.readyTimeout);
    } on TimeoutException {
      debugPrint(
        'FlowCraft splash: startup exceeded ${widget.readyTimeout}, '
        'proceeding to the whiteboard anyway.',
      );
    }

    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _ready
          ? const WhiteboardView(key: ValueKey('whiteboard'))
          : _SplashContent(
              key: const ValueKey('splash'),
              fade: _fade,
              scale: _scale,
            ),
    );
  }
}

/// The splash screen's static content: glowing logo, app name, and a small
/// loading affordance — everything that fades/scales in via [fade]/[scale].
class _SplashContent extends StatelessWidget {
  const _SplashContent({super.key, required this.fade, required this.scale});

  final Animation<double> fade;
  final Animation<double> scale;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;

    return Material(
      color: t.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: fade,
              child: ScaleTransition(scale: scale, child: const _GlowingLogo()),
            ),
            const SizedBox(height: AppSpacing.gutter),
            FadeTransition(
              opacity: fade,
              child: Text(
                'FlowCraft',
                style: AppTypography.headlineMd.copyWith(
                  color: t.text,
                  fontSize: 28,
                ),
              ),
            ),
            const SizedBox(height: 56),
            FadeTransition(
              opacity: fade,
              child: Column(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(t.accent),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loading workspace…',
                    style: AppTypography.caption.copyWith(color: t.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The logo badge (`assets/logo/my-logo.png`) over a soft radial glow that
/// echoes the artwork's own cyan neon rim. The PNG has a genuinely
/// transparent background (verified: 512x512 RGBA), so it's rendered as-is
/// with no backing container to hide seams.
class _GlowingLogo extends StatelessWidget {
  const _GlowingLogo();

  static const double _glowSize = 240;
  static const double _logoSize = 176;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _glowSize,
      height: _glowSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: _glowSize,
            height: _glowSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _logoGlowCyan.withValues(alpha: 0.33),
                  _logoGlowCyan.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
          Image.asset(
            'assets/logo/my-logo.png',
            width: _logoSize,
            height: _logoSize,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
