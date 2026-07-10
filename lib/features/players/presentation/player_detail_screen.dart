import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/models/player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/hyper_grid_background.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../core/widgets/top_bar.dart';

final _playerDetailProvider =
    FutureProvider.family<Player?, String>((ref, id) async {
  return ref.read(playerRepositoryProvider).fetchById(id);
});

class PlayerDetailScreen extends ConsumerWidget {
  final String id;

  const PlayerDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(_playerDetailProvider(id));

    return playerAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: TopBar(title: 'Player', showBack: true),
        body: HyperGridBackground(
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: TopBar(title: 'Player', showBack: true),
        body: HyperGridBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to load player.\n${e.toString()}',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ),
      data: (player) {
        if (player == null) {
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: TopBar(title: 'Player', showBack: true),
            body: HyperGridBackground(
              child: Center(
                child: Text(
                  'Player not found.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }

        final avatarColor = avatarColorForName(player.name);
        final hasJersey = player.jerseyNumber != null;

        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: TopBar(title: player.name, showBack: true),
          body: HyperGridBackground(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              children: [
                // ── Hero section ────────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      PlayerAvatarWidget(
                        name: player.name,
                        avatarUrl: player.avatarUrl,
                        color: avatarColor,
                        size: 80,
                      ).animate().fadeIn(duration: 300.ms).scale(
                            begin: const Offset(0.85, 0.85),
                            end: const Offset(1, 1),
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),
                      const SizedBox(height: 16),
                      Text(
                        player.name,
                        style: AppTextStyles.headingLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 80.ms, duration: 300.ms),
                      if (player.sport != null || player.role != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          [
                            if (player.sport != null)
                              player.sport!.substring(0, 1).toUpperCase() +
                                  player.sport!.substring(1),
                            if (player.role != null) player.role!,
                          ].join(' · '),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ).animate().fadeIn(delay: 120.ms, duration: 300.ms),
                      ],
                      if (hasJersey) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Text(
                            '#${player.jerseyNumber}',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ).animate().fadeIn(delay: 160.ms, duration: 300.ms),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Stats card ──────────────────────────────────────────────
                Text(
                  'Stats',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: player.stats.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No stats recorded yet',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: player.stats.entries.map((entry) {
                            return _StatCell(
                              label: entry.key,
                              value: entry.value.toString(),
                            );
                          }).toList(),
                        ),
                ).animate().fadeIn(delay: 220.ms, duration: 300.ms),
                const SizedBox(height: 24),

                // ── Info card ───────────────────────────────────────────────
                Text(
                  'Info',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ).animate().fadeIn(delay: 260.ms, duration: 300.ms),
                const SizedBox(height: 12),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'Sport',
                        value: player.sport != null
                            ? player.sport!.substring(0, 1).toUpperCase() +
                                player.sport!.substring(1)
                            : '—',
                        isFirst: true,
                      ),
                      const Divider(
                        height: 1,
                        color: AppColors.stroke,
                        indent: 16,
                        endIndent: 16,
                      ),
                      _InfoRow(
                        label: 'Role',
                        value: player.role ?? '—',
                      ),
                      const Divider(
                        height: 1,
                        color: AppColors.stroke,
                        indent: 16,
                        endIndent: 16,
                      ),
                      _InfoRow(
                        label: 'Jersey',
                        value: hasJersey ? '#${player.jerseyNumber}' : '—',
                        isLast: true,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 280.ms, duration: 300.ms),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isFirst;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        isFirst ? 16 : 12,
        16,
        isLast ? 16 : 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
