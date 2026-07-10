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
import '../../../core/widgets/search_bar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/top_bar.dart';

class TournamentsListScreen extends ConsumerStatefulWidget {
  const TournamentsListScreen({super.key});

  @override
  ConsumerState<TournamentsListScreen> createState() =>
      _TournamentsListScreenState();
}

class _TournamentsListScreenState
    extends ConsumerState<TournamentsListScreen> {
  String _selectedSport = 'All';
  final _searchController = TextEditingController();

  static const _sports = [
    'All', 'Football', 'Cricket', 'Badminton', 'eFootball'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Tournament> _filter(List<Tournament> all) {
    return all.where((t) {
      if (_selectedSport != 'All' &&
          t.sport.toLowerCase() != _selectedSport.toLowerCase()) return false;
      final q = _searchController.text.toLowerCase();
      if (q.isNotEmpty && !t.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tournamentsProvider(_selectedSport));

    return HyperGridBackground(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: TopBar(),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tournaments',
                          style: AppTextStyles.headingLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          async.maybeWhen(
                            data: (list) => '${list.length} active contests',
                            orElse: () => 'Loading...',
                          ),
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _ActionBtn(
                    icon: Icons.tune_rounded,
                    onTap: () => context.push('/tournaments/join'),
                    tooltip: 'Join',
                  ),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    icon: Icons.add_rounded,
                    onTap: () => context.push('/tournaments/create'),
                    tooltip: 'Create',
                    isPrimary: true,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: SearchInput(
                controller: _searchController,
                hint: 'Search tournaments...',
                onChanged: (_) => setState(() {}),
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 0, 8),
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 20),
                  itemCount: _sports.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _SportChip(
                    label: _sports[i],
                    isActive: _selectedSport == _sports[i],
                    onTap: () =>
                        setState(() => _selectedSport = _sports[i]),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
          ),
          async.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: AppColors.textTertiary, size: 40),
                    const SizedBox(height: 12),
                    Text('Could not load tournaments',
                        style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 6),
                    Text(e.toString(),
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textTertiary),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => ref.invalidate(tournamentsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (all) {
              final list = _filter(all);
              if (list.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.emoji_events_rounded,
                              color: AppColors.primary, size: 36),
                        ),
                        const SizedBox(height: 16),
                        Text('No tournaments found',
                            style: AppTextStyles.headingSmall),
                        const SizedBox(height: 6),
                        Text('Try adjusting your filters',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textTertiary)),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                );
              }
              return SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(20, 12, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TournamentCard(
                        tournament: list[i],
                        onTap: () =>
                            context.push('/tournaments/${list[i].id}'),
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(
                                milliseconds: 200 + i * 60),
                            duration: 400.ms,
                          )
                          .slideY(
                            begin: 0.15,
                            end: 0,
                            delay: Duration(
                                milliseconds: 200 + i * 60),
                            duration: 400.ms,
                            curve: Curves.easeOut,
                          ),
                    ),
                    childCount: list.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Tournament Card ────────────────────────────────────────────────────────

class _TournamentCard extends StatelessWidget {
  final Tournament tournament;
  final VoidCallback onTap;

  const _TournamentCard(
      {required this.tournament, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final start = tournament.startDate;
    final end = tournament.endDate;
    final dateRange = (start != null && end != null)
        ? '${_fmt(start)} – ${_fmt(end)}'
        : 'TBD';

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _SportIcon(sport: tournament.sport),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tournament.name,
                        style: AppTextStyles.headingSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusBadge(tournament.status),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                        tournament.type == 'individual'
                            ? Icons.person_rounded
                            : Icons.groups_rounded,
                        size: 12,
                        color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                        '${tournament.currentTeams} ${tournament.type == 'individual' ? 'players' : 'teams'}',
                        style: AppTextStyles.bodySmall),
                    const SizedBox(width: 12),
                    const Icon(Icons.calendar_today_rounded,
                        size: 12, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(dateRange,
                        style: AppTextStyles.bodySmall),
                  ],
                ),
                if (tournament.location != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    tournament.location!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textTertiary, size: 20),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${_month(d.month)} ${d.day}';

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  Widget _statusBadge(String status) => switch (status) {
        'live' => AppBadge.live(),
        'upcoming' => AppBadge.upcoming(),
        _ => AppBadge.completed(),
      };
}

class _SportIcon extends StatelessWidget {
  final String sport;
  const _SportIcon({required this.sport});

  IconData get _icon => switch (sport.toLowerCase()) {
        'football' => Icons.sports_soccer_rounded,
        'cricket' => Icons.sports_cricket_rounded,
        'basketball' => Icons.sports_basketball_rounded,
        'tennis' || 'badminton' => Icons.sports_tennis_rounded,
        _ => Icons.emoji_events_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Icon(_icon, color: AppColors.primary, size: 22),
    );
  }
}

class _SportChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SportChip(
      {required this.label,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primarySurface
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? AppColors.glassBorder
                : AppColors.stroke,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: isActive
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool isPrimary;

  const _ActionBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : AppColors.bgCard,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isPrimary
                ? Colors.transparent
                : AppColors.stroke,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isPrimary
              ? AppColors.textInverse
              : AppColors.textSecondary,
        ),
      ),
    );
  }
}
