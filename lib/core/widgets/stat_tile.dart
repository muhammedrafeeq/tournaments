import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'glass_card.dart';

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final String? trend;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 6),
              ],
              Text(label.toUpperCase(), style: AppTextStyles.overline),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.displaySmall.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (trend != null) ...[
            const SizedBox(height: 4),
            Text(trend!, style: AppTextStyles.bodySmall),
          ],
        ],
      ),
    );
  }
}

class StatRow extends StatelessWidget {
  final List<StatTile> stats;

  const StatRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: stats
          .asMap()
          .entries
          .map(
            (e) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: e.key > 0 ? 10 : 0),
                child: e.value,
              ),
            ),
          )
          .toList(),
    );
  }
}
