import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? fillColor;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  // legacy params kept for call-site compatibility
  final bool glowOnTap;
  final bool blur;
  final bool accent;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.fillColor,
    this.borderColor,
    this.borderWidth = 1,
    this.shadows,
    this.onTap,
    this.glowOnTap = true,
    this.width,
    this.height,
    this.blur = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: fillColor != null
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5, 1.0],
                colors: [
                  Color(0xFF1E2E22), // top-left: visibly lighter
                  Color(0xFF162018), // mid
                  Color(0xFF111A14), // bottom-right
                ],
              ),
        color: fillColor,
        border: Border.all(
          color: borderColor ?? AppColors.stroke,
          width: borderWidth,
        ),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withAlpha(70),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppColors.primaryGlow.withAlpha(10),
                blurRadius: 24,
                offset: const Offset(0, 2),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - borderWidth),
        child: Stack(
          children: [
            // ── Top-edge shine line ───────────────────────────────────
            Positioned(
              top: 0,
              left: borderRadius,
              right: borderRadius,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withAlpha(22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // ── Corner glow (top-left) ────────────────────────────────
            Positioned(
              top: -20,
              left: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withAlpha(8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // ── Content ───────────────────────────────────────────────
            Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: child,
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

// ── Primary variant ───────────────────────────────────────────────────────────

class GlassCardPrimary extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;

  const GlassCardPrimary({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      onTap: onTap,
      borderColor: AppColors.strokeBright,
      shadows: [
        BoxShadow(
          color: Colors.black.withAlpha(90),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: AppColors.primaryGlow.withAlpha(50),
          blurRadius: 36,
          spreadRadius: -6,
        ),
      ],
      child: Stack(
        children: [
          // Extra green gradient wash for primary cards
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius - 1),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withAlpha(18),
                    Colors.transparent,
                    AppColors.primary.withAlpha(6),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
