import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/tournament.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/hyper_grid_background.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/top_bar.dart';

class TournamentDashboardScreen extends ConsumerWidget {
  const TournamentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(tournamentsProvider(null));
    final profileAsync = ref.watch(currentProfileProvider);

    final username = profileAsync.maybeWhen(
      data: (p) => p?.username ?? 'Organizer',
      orElse: () => 'Organizer',
    );

    return HyperGridBackground(
      showGlowEdge: true,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: TopBar(),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Home',
                    style: AppTextStyles.headingLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome back, $username',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _HeroBanner(tournamentsAsync: allAsync),
            ).animate().fadeIn(delay: 100.ms, duration: 500.ms).slideY(
                begin: 0.1,
                end: 0,
                duration: 500.ms,
                curve: Curves.easeOut),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: allAsync.when(
                loading: () => _statsPlaceholder(),
                error: (err, st) => _statsPlaceholder(),
                data: (list) {
                  final live =
                      list.where((t) => t.status == 'live').length;
                  return StatRow(
                    stats: [
                      StatTile(
                        label: 'Active',
                        value: '$live',
                        icon: Icons.play_circle_rounded,
                        valueColor: AppColors.primary,
                      ),
                      StatTile(
                        label: 'Total',
                        value: '${list.length}',
                        icon: Icons.emoji_events_rounded,
                      ),
                      StatTile(
                        label: 'Upcoming',
                        value: '${list.where((t) => t.status == 'upcoming').length}',
                        icon: Icons.schedule_rounded,
                      ),
                    ],
                  );
                },
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child:
                  Text('Quick Actions', style: AppTextStyles.headingSmall),
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _QuickActions(),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Active Tournaments',
                      style: AppTextStyles.headingSmall),
                  GestureDetector(
                    onTap: () => context.go('/tournaments'),
                    child: Text('View all',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.primary)),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
          ),
          allAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text('Could not load tournaments',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textTertiary)),
              ),
            ),
            data: (all) {
              final live = all
                  .where((t) =>
                      t.status == 'live' || t.status == 'upcoming')
                  .take(5)
                  .toList();
              if (live.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.emoji_events_rounded,
                              color: AppColors.textTertiary, size: 40),
                          const SizedBox(height: 12),
                          Text('No active tournaments',
                              style: AppTextStyles.headingSmall
                                  .copyWith(
                                      color: AppColors.textTertiary)),
                          const SizedBox(height: 6),
                          Text(
                              'Create one to get started',
                              style: AppTextStyles.bodySmall
                                  .copyWith(
                                      color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(20, 12, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ActiveTournamentRow(
                        tournament: live[i],
                        onTap: () => context
                            .push('/tournaments/${live[i].id}'),
                      )
                          .animate()
                          .fadeIn(
                              delay: Duration(
                                  milliseconds: 300 + i * 60),
                              duration: 400.ms)
                          .slideY(
                              begin: 0.1,
                              end: 0,
                              delay: Duration(
                                  milliseconds: 300 + i * 60),
                              duration: 400.ms,
                              curve: Curves.easeOut),
                    ),
                    childCount: live.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statsPlaceholder() {
    return StatRow(
      stats: const [
        StatTile(
            label: 'Active',
            value: '—',
            icon: Icons.play_circle_rounded,
            valueColor: AppColors.primary),
        StatTile(
            label: 'Total',
            value: '—',
            icon: Icons.emoji_events_rounded),
        StatTile(
            label: 'Upcoming',
            value: '—',
            icon: Icons.schedule_rounded),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final AsyncValue<List<Tournament>> tournamentsAsync;
  const _HeroBanner({required this.tournamentsAsync});

  @override
  Widget build(BuildContext context) {
    final liveCount = tournamentsAsync.maybeWhen(
      data: (list) => list.where((t) => t.status == 'live').length,
      orElse: () => 0,
    );
    final matchesToday = tournamentsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    return GlassCardPrimary(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOURNAMENT SEASON',
                    style: AppTextStyles.overlinePrimary),
                const SizedBox(height: 8),
                Text(
                  '$liveCount Tournament${liveCount == 1 ? '' : 's'}\nIn Progress',
                  style: AppTextStyles.headingLarge,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    AppBadge.live(label: 'LIVE NOW'),
                    const SizedBox(width: 8),
                    Text('$matchesToday total events',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryGlow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: AppColors.primary, size: 42),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _QA(Icons.add_circle_rounded, 'Create\nTournament',
          AppColors.primary,
          () => context.push('/tournaments/create')),
      _QA(Icons.groups_rounded, 'Manage\nTeams',
          AppColors.info, () => context.go('/teams')),
      _QA(Icons.person_rounded, 'Players',
          AppColors.gold, () => context.go('/players')),
      _QA(Icons.bar_chart_rounded, 'Statistics',
          AppColors.warning, () {}),
    ];

    return Row(
      children: actions.asMap().entries.map((e) {
        final i = e.key;
        final a = e.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i > 0 ? 10 : 0),
            child: GlassCard(
              onTap: a.onTap,
              padding: const EdgeInsets.symmetric(
                  vertical: 16, horizontal: 12),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: a.color.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(a.icon, color: a.color, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    a.label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ActiveTournamentRow extends StatelessWidget {
  final Tournament tournament;
  final VoidCallback onTap;

  const _ActiveTournamentRow(
      {required this.tournament, required this.onTap});

  IconData get _sportIcon => switch (tournament.sport.toLowerCase()) {
        'football' => Icons.sports_soccer_rounded,
        'cricket' => Icons.sports_cricket_rounded,
        'basketball' => Icons.sports_basketball_rounded,
        _ => Icons.emoji_events_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final maxTeams = tournament.maxTeams;
    final curTeams = tournament.currentTeams;
    final progress =
        maxTeams > 0 ? (curTeams / maxTeams).clamp(0.0, 1.0) : 0.0;

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Icon(_sportIcon,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tournament.name,
                        style: AppTextStyles.headingSmall),
                    const SizedBox(height: 2),
                    Text('$curTeams / ${maxTeams > 0 ? maxTeams : '?'} teams',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              tournament.status == 'live'
                  ? AppBadge.live()
                  : AppBadge.upcoming(),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 18),
            ],
          ),
          if (maxTeams > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.stroke,
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(progress * 100).toInt()}% filled',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primary)),
                Text('${maxTeams - curTeams} spots left',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ],
        ],
      ),
    );
  }
}



class _QA {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QA(this.icon, this.label, this.color, this.onTap);
}
