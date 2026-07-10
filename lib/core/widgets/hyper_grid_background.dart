import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Plain premium background — deep dark with a subtle radial glow at the top.
class HyperGridBackground extends StatelessWidget {
  final Widget child;
  final bool showGlowEdge;

  const HyperGridBackground({
    super.key,
    required this.child,
    this.showGlowEdge = false,
    // ignored legacy params kept for call-site compatibility
    double gridSize = 28,
    double lineOpacity = 1.0,
    bool showDots = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient background
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A1210),
                  AppColors.bg,
                ],
              ),
            ),
          ),
        ),
        // Optional top glow (used on login / hero screens)
        if (showGlowEdge)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 260,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [
                    AppColors.primary.withAlpha(28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}

class ScorioScaffold extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool extendBodyBehindAppBar;
  final Color? backgroundColor;

  const ScorioScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.extendBodyBehindAppBar = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.bg,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: HyperGridBackground(child: child),
    );
  }
}
