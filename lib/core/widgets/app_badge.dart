import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum BadgeVariant { success, danger, warning, info, neutral, gold, live }

class AppBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final IconData? icon;
  final bool pulse;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.neutral,
    this.icon,
    this.pulse = false,
  });

  factory AppBadge.live({String label = 'LIVE'}) =>
      AppBadge(label: label, variant: BadgeVariant.live, pulse: true);

  factory AppBadge.upcoming({String label = 'UPCOMING'}) =>
      AppBadge(label: label, variant: BadgeVariant.info);

  factory AppBadge.completed({String label = 'DONE'}) =>
      AppBadge(label: label, variant: BadgeVariant.neutral);

  _BadgeStyle get _style {
    return switch (variant) {
      BadgeVariant.success => _BadgeStyle(
          bg: AppColors.primarySurface,
          border: AppColors.primary.withAlpha(100),
          text: AppColors.primary,
          dot: AppColors.primary,
        ),
      BadgeVariant.danger => _BadgeStyle(
          bg: AppColors.danger.withAlpha(30),
          border: AppColors.danger.withAlpha(100),
          text: AppColors.danger,
          dot: AppColors.danger,
        ),
      BadgeVariant.live => _BadgeStyle(
          bg: AppColors.liveGlow,
          border: AppColors.danger.withAlpha(120),
          text: AppColors.danger,
          dot: AppColors.danger,
        ),
      BadgeVariant.warning => _BadgeStyle(
          bg: AppColors.warning.withAlpha(30),
          border: AppColors.warning.withAlpha(100),
          text: AppColors.warning,
          dot: AppColors.warning,
        ),
      BadgeVariant.gold => _BadgeStyle(
          bg: AppColors.gold.withAlpha(30),
          border: AppColors.gold.withAlpha(100),
          text: AppColors.gold,
          dot: AppColors.gold,
        ),
      BadgeVariant.info => _BadgeStyle(
          bg: AppColors.info.withAlpha(25),
          border: AppColors.info.withAlpha(75),
          text: AppColors.info,
          dot: AppColors.info,
        ),
      BadgeVariant.neutral => _BadgeStyle(
          bg: AppColors.bgCard,
          border: AppColors.stroke,
          text: AppColors.textSecondary,
          dot: AppColors.textTertiary,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    Widget dot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: s.dot, shape: BoxShape.circle),
    );

    if (pulse) {
      dot = dot
          .animate(onPlay: (c) => c.repeat())
          .fadeIn(duration: 600.ms)
          .then()
          .fadeOut(duration: 600.ms);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: s.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: s.text),
            const SizedBox(width: 4),
          ] else ...[
            dot,
            const SizedBox(width: 5),
          ],
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: s.text)),
        ],
      ),
    );
  }
}

class _BadgeStyle {
  final Color bg, border, text, dot;
  const _BadgeStyle({
    required this.bg,
    required this.border,
    required this.text,
    required this.dot,
  });
}
