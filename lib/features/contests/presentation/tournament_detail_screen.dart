import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/match.dart';
import '../../../core/models/player.dart';
import '../../../core/models/team.dart';
import '../../../core/models/tournament.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/hyper_grid_background.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/top_bar.dart';

class TournamentDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const TournamentDetailScreen({super.key, required this.id});

  @override
  ConsumerState<TournamentDetailScreen> createState() =>
      _TournamentDetailScreenState();
}

class _TournamentDetailScreenState
    extends ConsumerState<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _tabsCount = 4;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabsCount, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tournamentAsync =
        ref.watch(tournamentDetailProvider(widget.id));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: tournamentAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppColors.textTertiary, size: 40),
              const SizedBox(height: 12),
              Text('Could not load tournament',
                  style: AppTextStyles.bodyMedium),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    ref.invalidate(tournamentDetailProvider(widget.id)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (tournament) {
          if (tournament == null) {
            return Center(
              child: Text('Tournament not found',
                  style: AppTextStyles.bodyMedium),
            );
          }
          return HyperGridBackground(
            child: NestedScrollView(
              headerSliverBuilder: (ctx, _) => [
                SliverToBoxAdapter(
                    child: _buildHeader(context, tournament)),
                SliverToBoxAdapter(
                    child: _buildHeroCard(tournament)),
                SliverToBoxAdapter(child: _buildTabBar(tournament)),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _MatchesTab(
                      id: widget.id,
                      sport: tournament.sport,
                      isIndividual: tournament.type == 'individual'),
                  _StandingsTab(tournamentId: widget.id),
                  _TeamsTab(tournament: tournament),
                  _BracketTab(tournamentId: widget.id),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildHeader(BuildContext context, Tournament t) {
    return TopBar(
      title: t.name,
      showBack: true,
      actions: [
        _ActionBtn(icon: Icons.share_rounded, onTap: () {}),
        PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'delete') {
              _showDeleteConfirmDialog(context, t);
            }
          },
          color: AppColors.bgCard,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.stroke)),
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_rounded, color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Text('Delete Tournament',
                      style: TextStyle(color: AppColors.danger)),
                ],
              ),
            ),
          ],
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.stroke),
            ),
            child: const Icon(Icons.more_vert_rounded,
                size: 18, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Tournament t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Tournament', style: AppTextStyles.headingSmall),
        content: Text('Are you sure you want to delete "${t.name}"? This action cannot be undone and will delete all enrolled participants and scheduled matches.', style: AppTextStyles.bodySmall),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              
              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                ),
              );

              try {
                await ref.read(tournamentRepositoryProvider).delete(t.id);
                ref.invalidate(tournamentsProvider);
                if (context.mounted) {
                  Navigator.pop(context); // Close loading dialog
                  context.pop(); // Go back to tournament list
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete tournament: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(Tournament t) {
    final sportIcon = _sportIcon(t.sport);
    final start = t.startDate;
    final end = t.endDate;
    final dateLabel = (start != null && end != null)
        ? '${_fmt(start)} – ${_fmt(end)}'
        : 'TBD';
    final isIndividual = t.type == 'individual';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GlassCardPrimary(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGlow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(sportIcon,
                      color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(t.sport.toUpperCase(),
                              style: AppTextStyles.overlinePrimary),
                          const SizedBox(width: 8),
                          _statusBadge(t.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatLabel(t)} · ${t.currentTeams} ${isIndividual ? "Players" : "Teams"}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _StatPill(
                  icon: isIndividual ? Icons.person_rounded : Icons.groups_rounded,
                  label: '${t.currentTeams} ${isIndividual ? "Players" : "Teams"}',
                ),
                if (t.location != null)
                  _StatPill(
                    icon: Icons.location_on_rounded,
                    label: t.location!,
                  ),
                _StatPill(
                  icon: Icons.calendar_today_rounded,
                  label: dateLabel,
                ),
              ],
            ),
            if (t.description?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              Divider(color: AppColors.stroke.withAlpha(50), height: 1),
              const SizedBox(height: 14),
              Text(
                t.description!,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (t.inviteCode != null) ...[
              const SizedBox(height: 14),
              Divider(color: AppColors.stroke.withAlpha(50), height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.vpn_key_rounded, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 8),
                  Text('Code  ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
                  Expanded(
                    child: Text(
                      t.inviteCode!,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primary,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: t.inviteCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied!')),
                      );
                    },
                    child: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
    );
  }

  Widget _buildTabBar(Tournament t) {
    final isIndividual = t.type == 'individual';
    final tabs = ['Matches', 'Standings', isIndividual ? 'Players' : 'Teams', 'Bracket'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.stroke),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.glassBorder),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelPadding:
              const EdgeInsets.symmetric(horizontal: 4),
          dividerColor: Colors.transparent,
          tabs: tabs
              .map((t) => Tab(
                    child: Text(t,
                        style: AppTextStyles.labelSmall
                            .copyWith(fontSize: 11)),
                  ))
              .toList(),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${_month(d.month)} ${d.day}';

  String _month(int m) => const [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][m];

  String _formatLabel(Tournament t) => switch (t.status) {
        'live' => 'Live',
        'upcoming' => 'Upcoming',
        _ => 'Completed',
      };

  Widget _statusBadge(String status) => switch (status) {
        'live' => AppBadge.live(),
        'upcoming' => AppBadge.upcoming(),
        _ => AppBadge.completed(),
      };

  IconData _sportIcon(String sport) =>
      switch (sport.toLowerCase()) {
        'football' => Icons.sports_soccer_rounded,
        'cricket' => Icons.sports_cricket_rounded,
        'basketball' => Icons.sports_basketball_rounded,
        'tennis' || 'badminton' =>
          Icons.sports_tennis_rounded,
        _ => Icons.emoji_events_rounded,
      };
}

// ── Overview Tab ───────────────────────────────────────────────────────────

// ── Standings Tab ──────────────────────────────────────────────────────────

class _StandingRowData {
  final String teamId;
  final String teamName;
  final String? colorHex;
  int played = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  double points = 0.0;

  _StandingRowData({required this.teamId, required this.teamName, this.colorHex});
}

class _StandingsTab extends ConsumerWidget {
  final String tournamentId;
  const _StandingsTab({required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentAsync = ref.watch(tournamentDetailProvider(tournamentId));
    final teamsAsync = ref.watch(tournamentTeamsProvider(tournamentId));
    final matchesAsync = ref.watch(tournamentMatchesStreamProvider(tournamentId));

    return tournamentAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
      ),
      error: (e, _) => Center(
        child: Text('Could not load tournament: $e', style: AppTextStyles.bodyMedium),
      ),
      data: (tournament) {
        if (tournament == null) {
          return const Center(child: Text('Tournament not found'));
        }

        final sport = tournament.sport.toLowerCase();

        return teamsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
          ),
          error: (e, _) => Center(
            child: Text('Could not load standings: $e', style: AppTextStyles.bodyMedium),
          ),
          data: (teams) {
            return matchesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              ),
              error: (e, _) => Center(
                child: Text('Could not load matches: $e', style: AppTextStyles.bodyMedium),
              ),
              data: (matches) {
                final isGroupFormat = tournament.type == 'groups_knockout' || matches.any((m) => m.metadata.containsKey('group'));

                String getGroupForTeam(String teamId) {
                  for (final m in matches) {
                    if ((m.homeTeamId == teamId || m.awayTeamId == teamId) && m.metadata.containsKey('group')) {
                      return m.metadata['group'] as String;
                    }
                  }
                  return 'Group A';
                }

                final groupedRows = <String, List<_StandingRowData>>{};

                for (final team in teams) {
                  final groupName = isGroupFormat ? getGroupForTeam(team.id) : 'Standings';
                  final row = _StandingRowData(
                    teamId: team.id,
                    teamName: team.name,
                    colorHex: team.colorHex,
                  );
                  groupedRows.putIfAbsent(groupName, () => []).add(row);
                }

                for (final match in matches) {
                  if (match.status == 'completed') {
                    final homeId = match.homeTeamId;
                    final awayId = match.awayTeamId;
                    final homeScore = match.homeScore ?? 0;
                    final awayScore = match.awayScore ?? 0;

                    final groupName = isGroupFormat
                        ? (match.metadata['group'] as String? ?? getGroupForTeam(homeId ?? ''))
                        : 'Standings';
                    final groupList = groupedRows[groupName];

                    if (groupList != null) {
                      if (homeId != null) {
                        final row = groupList.firstWhere((r) => r.teamId == homeId, orElse: () => _StandingRowData(teamId: homeId, teamName: ''));
                        if (row.teamName.isNotEmpty) {
                          row.played++;
                          row.goalsFor += homeScore;
                          row.goalsAgainst += awayScore;

                          if (sport == 'chess') {
                            if (homeScore > awayScore) {
                              row.won++;
                              row.points += 1.0;
                            } else if (homeScore == awayScore) {
                              row.drawn++;
                              row.points += 0.5;
                            } else {
                              row.lost++;
                            }
                          } else if (sport == 'badminton' || sport == 'tennis') {
                            if (homeScore > awayScore) {
                              row.won++;
                              row.points += 1.0;
                            } else {
                              row.lost++;
                            }
                          } else if (sport == 'cricket') {
                            if (homeScore > awayScore) {
                              row.won++;
                              row.points += 2.0;
                            } else if (homeScore == awayScore) {
                              row.drawn++;
                              row.points += 1.0;
                            } else {
                              row.lost++;
                            }
                          } else {
                            if (homeScore > awayScore) {
                              row.won++;
                              row.points += 3.0;
                            } else if (homeScore == awayScore) {
                              row.drawn++;
                              row.points += 1.0;
                            } else {
                              row.lost++;
                            }
                          }
                        }
                      }

                      if (awayId != null) {
                        final row = groupList.firstWhere((r) => r.teamId == awayId, orElse: () => _StandingRowData(teamId: awayId, teamName: ''));
                        if (row.teamName.isNotEmpty) {
                          row.played++;
                          row.goalsFor += awayScore;
                          row.goalsAgainst += homeScore;

                          if (sport == 'chess') {
                            if (awayScore > homeScore) {
                              row.won++;
                              row.points += 1.0;
                            } else if (awayScore == homeScore) {
                              row.drawn++;
                              row.points += 0.5;
                            } else {
                              row.lost++;
                            }
                          } else if (sport == 'badminton' || sport == 'tennis') {
                            if (awayScore > homeScore) {
                              row.won++;
                              row.points += 1.0;
                            } else {
                              row.lost++;
                            }
                          } else if (sport == 'cricket') {
                            if (awayScore > homeScore) {
                              row.won++;
                              row.points += 2.0;
                            } else if (awayScore == homeScore) {
                              row.drawn++;
                              row.points += 1.0;
                            } else {
                              row.lost++;
                            }
                          } else {
                            if (awayScore > homeScore) {
                              row.won++;
                              row.points += 3.0;
                            } else if (awayScore == homeScore) {
                              row.drawn++;
                              row.points += 1.0;
                            } else {
                              row.lost++;
                            }
                          }
                        }
                      }
                    }
                  }
                }

                if (groupedRows.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('No participants enrolled yet', style: AppTextStyles.bodyMedium),
                    ),
                  );
                }

                final groupNames = groupedRows.keys.toList()..sort();

                List<DataColumn> getColumns() {
                  if (sport == 'football' || sport == 'efootball') {
                    return const [
                      DataColumn(label: Text('Pos')),
                      DataColumn(label: Text('Participant')),
                      DataColumn(label: Text('P')),
                      DataColumn(label: Text('W')),
                      DataColumn(label: Text('D')),
                      DataColumn(label: Text('L')),
                      DataColumn(label: Text('GD')),
                      DataColumn(label: Text('Pts')),
                    ];
                  } else if (sport == 'chess') {
                    return const [
                      DataColumn(label: Text('Pos')),
                      DataColumn(label: Text('Participant')),
                      DataColumn(label: Text('P')),
                      DataColumn(label: Text('W')),
                      DataColumn(label: Text('D')),
                      DataColumn(label: Text('L')),
                      DataColumn(label: Text('Pts')),
                    ];
                  } else {
                    return const [
                      DataColumn(label: Text('Pos')),
                      DataColumn(label: Text('Participant')),
                      DataColumn(label: Text('P')),
                      DataColumn(label: Text('W')),
                      DataColumn(label: Text('L')),
                      DataColumn(label: Text('Pts')),
                    ];
                  }
                }

                List<DataCell> getRowCells(int idx, _StandingRowData row, Color color) {
                  final gd = row.goalsFor - row.goalsAgainst;
                  final gdStr = gd > 0 ? '+$gd' : '$gd';
                  final ptsStr = sport == 'chess'
                      ? row.points.toString().replaceAll(RegExp(r'\.0$'), '')
                      : '${row.points.toInt()}';

                  final medal = idx == 0 ? '🥇' : idx == 1 ? '🥈' : idx == 2 ? '🥉' : null;

                  final cells = [
                    DataCell(Center(
                      child: medal != null
                          ? Text(medal, style: const TextStyle(fontSize: 14))
                          : Text('${idx + 1}',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.textSecondary)),
                    )),
                    DataCell(
                      Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(row.teamName, style: AppTextStyles.labelSmall),
                        ],
                      ),
                    ),
                    DataCell(Center(child: Text('${row.played}'))),
                    DataCell(Center(child: Text('${row.won}'))),
                  ];

                  if (sport == 'football' || sport == 'efootball' || sport == 'chess') {
                    cells.add(DataCell(Center(child: Text('${row.drawn}'))));
                  }

                  cells.add(DataCell(Center(child: Text('${row.lost}'))));

                  if (sport == 'football' || sport == 'efootball') {
                    cells.add(DataCell(Center(child: Text(gdStr, style: TextStyle(color: gd > 0 ? AppColors.primary : gd < 0 ? AppColors.danger : AppColors.textTertiary)))));
                  }

                  cells.add(DataCell(Center(child: Text(ptsStr, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)))));

                  return cells;
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  itemCount: groupNames.length,
                  itemBuilder: (context, gIdx) {
                    final gName = groupNames[gIdx];
                    final sorted = groupedRows[gName]!;

                    sorted.sort((a, b) {
                      if (a.points != b.points) return b.points.compareTo(a.points);
                      final gdA = a.goalsFor - a.goalsAgainst;
                      final gdB = b.goalsFor - b.goalsAgainst;
                      if (gdA != gdB) return gdB.compareTo(gdA);
                      if (a.goalsFor != b.goalsFor) return b.goalsFor.compareTo(a.goalsFor);
                      return a.teamName.compareTo(b.teamName);
                    });

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (gIdx > 0) const SizedBox(height: 24),
                        _SectionHeader(title: gName),
                        const SizedBox(height: 14),
                        GlassCard(
                          padding: EdgeInsets.zero,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: DataTable(
                                    horizontalMargin: 12,
                                    columnSpacing: 14,
                                    headingTextStyle: AppTextStyles.overline.copyWith(color: AppColors.textTertiary),
                                    dataTextStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                                    columns: getColumns(),
                                    rows: sorted.asMap().entries.map((e) {
                                      final idx = e.key;
                                      final row = e.value;
                                      final color = row.colorHex != null
                                          ? Color(int.parse('FF${row.colorHex!.replaceAll('#', '')}', radix: 16))
                                          : AppColors.primary;

                                      return DataRow(
                                        cells: getRowCells(idx, row, color),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Matches Tab ────────────────────────────────────────────────────────────

class _MatchesTab extends ConsumerWidget {
  final String id;
  final String sport;
  final bool isIndividual;
  const _MatchesTab({required this.id, required this.sport, required this.isIndividual});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(tournamentMatchesStreamProvider(id));

    return matchesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
            color: AppColors.primary, strokeWidth: 2),
      ),
      error: (e, _) => Center(
        child: Text('Could not load matches',
            style: AppTextStyles.bodyMedium),
      ),
      data: (matches) {
        if (matches.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sports_rounded,
                    color: AppColors.textTertiary, size: 40),
                const SizedBox(height: 12),
                Text('No matches scheduled yet',
                    style: AppTextStyles.headingSmall
                        .copyWith(color: AppColors.textTertiary)),
                const SizedBox(height: 6),
                Text('Tap "Score Match" to add one',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textTertiary)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: matches.length,
          itemBuilder: (ctx, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MatchCard(
                  match: matches[i],
                  index: i,
                  isIndividual: isIndividual,
                  onTap: () => context.push(
                    Uri(
                      path: '/tournaments/$id/matches/${matches[i].id}',
                      queryParameters: {
                        'sport': sport,
                        'home': matches[i].homeTeamName ?? 'Home',
                        'away': matches[i].awayTeamName ?? 'Away',
                      },
                    ).toString(),
                  ),
                ),
                if (matches[i].status == 'scheduled')
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: Icon(Icons.schedule_rounded, size: 14, color: AppColors.primary),
                      label: Text('Set Time', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                      onPressed: () => _scheduleMatch(context, ref, matches[i]),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _scheduleMatch(BuildContext context, WidgetRef ref, Match match) async {
    final date = await showDatePicker(
      context: context,
      initialDate: match.scheduledAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(match.scheduledAt ?? DateTime.now()),
    );
    if (time == null || !context.mounted) return;
    final scheduled = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await ref.read(tournamentRepositoryProvider).scheduleMatch(match.id, scheduled);
    ref.invalidate(tournamentMatchesStreamProvider(id));
  }
}

class _MatchCard extends StatelessWidget {
  final Match match;
  final int index;
  final bool isIndividual;
  final VoidCallback onTap;

  const _MatchCard(
      {required this.match, required this.index, required this.isIndividual, required this.onTap});

  Widget _buildStatusWidget() {
    final isLive = match.status == 'live';
    final isCompleted = match.status == 'completed';

    if (isLive) {
      String detail = 'Live';
      final sportLower = match.sport.toLowerCase();
      if (sportLower == 'football') {
        int liveMin = match.metadata['minute'] ?? 0;
        if (match.metadata['isRunning'] == true && match.metadata['clockStartedAt'] != null) {
          final started = DateTime.tryParse(match.metadata['clockStartedAt'].toString());
          if (started != null) {
            liveMin += DateTime.now().difference(started).inMinutes;
          }
        }
        detail = "$liveMin'";
      } else if (sportLower == 'chess') {
        if (match.metadata.containsKey('whiteSeconds')) {
          final w = match.metadata['whiteSeconds'] as int? ?? 0;
          final b = match.metadata['blackSeconds'] as int? ?? 0;
          final wm = w ~/ 60;
          final ws = w % 60;
          final bm = b ~/ 60;
          final bs = b % 60;
          detail = '${wm.toString().padLeft(2, '0')}:${ws.toString().padLeft(2, '0')} vs ${bm.toString().padLeft(2, '0')}:${bs.toString().padLeft(2, '0')}';
        }
      } else if (sportLower == 'badminton') {
        final cur = (match.metadata['games'] as List?)?.length ?? 1;
        detail = 'Game $cur';
      } else if (sportLower == 'tennis') {
        final cur = (match.metadata['sets'] as List?)?.length ?? 1;
        detail = 'Set $cur';
      } else if (sportLower == 'basketball') {
        final q = match.metadata['quarter'] ?? 1;
        detail = 'Q$q';
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.danger.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.danger.withAlpha(90)),
            ),
            child: Text(detail, style: AppTextStyles.labelSmall.copyWith(color: AppColors.danger)),
          ),
          const SizedBox(width: 6),
          AppBadge.live(),
        ],
      );
    } else if (isCompleted) {
      String detail = 'Full Time';
      final sportLower = match.sport.toLowerCase();
      if (sportLower == 'chess' || sportLower == 'badminton' || sportLower == 'tennis') {
        detail = 'Finished';
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(detail, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
          const SizedBox(width: 6),
          AppBadge.completed(),
        ],
      );
    } else {
      return _DateChip(
        label: match.scheduledAt != null
            ? '${_month(match.scheduledAt!.month)} ${match.scheduledAt!.day}'
            : 'TBD',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == 'live';
    final isCompleted = match.status == 'completed';
    final home = match.homeTeamName ?? 'Home';
    final away = match.awayTeamName ?? 'Away';

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        borderColor:
            isLive ? AppColors.danger.withAlpha(89) : null,
        child: Column(
          children: [
            Row(
              children: [
                Text('Match ${index + 1}',
                    style: AppTextStyles.overline),
                const Spacer(),
                _buildStatusWidget(),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TeamSlot(
                    name: home,
                    align: CrossAxisAlignment.start,
                    iconColor: AppColors.primary,
                    isIndividual: isIndividual,
                  ),
                ),
                _ScoreBox(
                  isLive: isLive,
                  isCompleted: isCompleted,
                  home: match.homeScore?.toString() ?? '',
                  away: match.awayScore?.toString() ?? '',
                ),
                Expanded(
                  child: _TeamSlot(
                    name: away,
                    align: CrossAxisAlignment.end,
                    iconColor: AppColors.textTertiary,
                    isIndividual: isIndividual,
                  ),
                ),
              ],
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(
              delay:
                  Duration(milliseconds: 100 + index * 50),
              duration: 350.ms),
    );
  }

  String _month(int m) => const [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][m];
}

// ── Teams Tab ──────────────────────────────────────────────────────────────

class _TeamsTab extends ConsumerWidget {
  final Tournament tournament;
  const _TeamsTab({required this.tournament});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIndividual = tournament.type == 'individual';
    final teamsAsync = ref.watch(tournamentTeamsProvider(tournament.id));
    final liveIdsAsync = ref.watch(liveTeamIdsProvider);

    return teamsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
            color: AppColors.primary, strokeWidth: 2),
      ),
      error: (e, _) => Center(
        child: Text(
            isIndividual ? 'Could not load players' : 'Could not load teams',
            style: AppTextStyles.bodyMedium),
      ),
      data: (teams) {
        if (teams.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    isIndividual ? Icons.person_rounded : Icons.groups_rounded,
                    color: AppColors.textTertiary, size: 48),
                const SizedBox(height: 16),
                Text(
                    isIndividual ? 'No players enrolled yet' : 'No teams enrolled yet',
                    style: AppTextStyles.headingSmall
                        .copyWith(color: AppColors.textTertiary)),
                const SizedBox(height: 8),
                Text(
                    isIndividual ? 'Players will appear here once they join' : 'Teams will appear here once they join',
                    style: AppTextStyles.bodySmall),
                const SizedBox(height: 20),
                _AddParticipantButton(tournament: tournament),
              ],
            ),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${teams.length} ${isIndividual ? "players" : "teams"} enrolled',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  _AddParticipantButton(tournament: tournament, isTextButton: true),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                itemCount: teams.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TournamentTeamCard(
                    team: teams[i],
                    index: i,
                    isIndividual: isIndividual,
                    isInLiveTournament: liveIdsAsync.valueOrNull?.contains(teams[i].id) ?? false,
                  )
                      .animate()
                      .fadeIn(
                          delay: Duration(milliseconds: 100 + i * 60),
                          duration: 350.ms),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TournamentTeamCard extends ConsumerStatefulWidget {
  final Team team;
  final int index;
  final bool isIndividual;
  final bool isInLiveTournament;
  const _TournamentTeamCard({
    required this.team,
    required this.index,
    required this.isIndividual,
    this.isInLiveTournament = false,
  });

  @override
  ConsumerState<_TournamentTeamCard> createState() =>
      _TournamentTeamCardState();
}

class _TournamentTeamCardState
    extends ConsumerState<_TournamentTeamCard> {
  bool _expanded = false;

  Color get _teamColor {
    final hex = widget.team.colorHex;
    if (hex == null) return AppColors.primary;
    try {
      return Color(
          int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  String get _initials => widget.team.name
      .split(' ')
      .take(2)
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final color = _teamColor;

    if (widget.isIndividual) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withAlpha(80)),
              ),
              child: Center(
                child: Text(_initials,
                    style: AppTextStyles.labelMedium
                        .copyWith(color: color, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(widget.team.name, style: AppTextStyles.headingSmall)),
                      if (widget.isInLiveTournament) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withAlpha(30),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: AppColors.danger.withAlpha(100)),
                          ),
                          child: Text('LIVE',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.danger, fontSize: 8)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(widget.team.sport.toUpperCase(),
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textTertiary)),
                ],
              ),
            ),
            Icon(Icons.person_rounded, color: color.withAlpha(150), size: 20),
          ],
        ),
      );
    }

    final playersAsync = ref.watch(teamPlayersProvider(widget.team.id));

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: color.withAlpha(80)),
                    ),
                    child: Center(
                      child: Text(_initials,
                          style: AppTextStyles.labelMedium
                              .copyWith(color: color)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.team.name,
                            style: AppTextStyles.headingSmall),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.team.playerCount} players · ${widget.team.sport}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, thickness: 1, color: AppColors.stroke),
            playersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Could not load players',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textTertiary)),
              ),
              data: (players) {
                if (players.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No players in this team yet',
                        style: AppTextStyles.bodySmall
                            .copyWith(
                                color: AppColors.textTertiary)),
                  );
                }
                return Column(
                  children: players
                      .map((p) => _PlayerRow(player: p))
                      .toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final Player player;
  const _PlayerRow({required this.player});

  String get _initials {
    final parts = player.name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return player.name.substring(0, player.name.length.clamp(0, 2)).toUpperCase();
  }

  Color get _avatarColor {
    final colors = [
      AppColors.primary,
      AppColors.info,
      AppColors.gold,
      AppColors.warning,
      AppColors.danger,
    ];
    return colors[player.name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _avatarColor.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _avatarColor.withAlpha(60)),
            ),
            child: Center(
              child: Text(_initials,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: _avatarColor)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name,
                    style: AppTextStyles.labelMedium),
                if (player.role != null || player.sport != null)
                  Text(
                    player.role ?? player.sport ?? '',
                    style: AppTextStyles.bodySmall,
                  ),
              ],
            ),
          ),
          if (player.jerseyNumber != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Text('#${player.jerseyNumber}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }
}

// ── Bracket Tab ────────────────────────────────────────────────────────────

class _BracketTab extends ConsumerWidget {
  final String tournamentId;
  const _BracketTab({required this.tournamentId});

  static const double _cardH = 76;
  static const double _cardW = 164;
  static const double _colGap = 52;
  static const double _colStride = _cardW + _colGap;
  static const double _headerH = 34;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(tournamentMatchesStreamProvider(tournamentId));

    return matchesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
      ),
      error: (e, _) => Center(
        child: Text('Could not load bracket', style: AppTextStyles.bodyMedium),
      ),
      data: (matches) {
        final bracketMatches =
            matches.where((m) => m.metadata.containsKey('round')).toList();

        if (bracketMatches.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_tree_rounded,
                    color: AppColors.textTertiary, size: 48),
                const SizedBox(height: 16),
                Text('Knockout Bracket',
                    style: AppTextStyles.headingSmall
                        .copyWith(color: AppColors.textTertiary)),
                const SizedBox(height: 8),
                Text('Available after the bracket draw',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          );
        }

        final roundMap = <String, List<Match>>{};
        for (final m in bracketMatches) {
          final round = m.metadata['round']?.toString() ?? 'Round';
          roundMap.putIfAbsent(round, () => []).add(m);
        }
        final rounds = roundMap.keys.toList()..sort();
        final roundLists = rounds.map((r) => roundMap[r]!).toList();

        final int maxMatches =
            roundLists.isEmpty ? 1 : roundLists[0].length;
        final double bodyH = maxMatches * (_cardH + 12) - 12;
        final double totalW =
            roundLists.length * _colStride - _colGap;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: SizedBox(
            width: totalW,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Round headers
                Row(
                  children: rounds.asMap().entries.map((e) {
                    final isLast = e.key == rounds.length - 1;
                    return SizedBox(
                      width: isLast ? _cardW : _colStride,
                      child: Container(
                        height: _headerH,
                        margin: EdgeInsets.only(right: isLast ? 0 : _colGap),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Text(e.value,
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.primary)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Bracket body: cards + connector lines
                SizedBox(
                  height: bodyH,
                  width: totalW,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _BracketConnectorPainter(
                            roundLists: roundLists,
                            cardH: _cardH,
                            cardW: _cardW,
                            colStride: _colStride,
                          ),
                        ),
                      ),
                      ...roundLists.asMap().entries.expand((rEntry) {
                        final rIdx = rEntry.key;
                        final rMatches = rEntry.value;
                        final slotH = bodyH / rMatches.length;
                        return rMatches.asMap().entries.map((mEntry) {
                          final mIdx = mEntry.key;
                          final match = mEntry.value;
                          final x = rIdx * _colStride;
                          final y = slotH * mIdx + (slotH - _cardH) / 2;
                          return Positioned(
                            left: x,
                            top: y,
                            width: _cardW,
                            height: _cardH,
                            child: _BracketCard(match: match),
                          );
                        });
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BracketConnectorPainter extends CustomPainter {
  final List<List<Match>> roundLists;
  final double cardH;
  final double cardW;
  final double colStride;

  const _BracketConnectorPainter({
    required this.roundLists,
    required this.cardH,
    required this.cardW,
    required this.colStride,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (roundLists.length < 2) return;
    final paint = Paint()
      ..color = AppColors.stroke
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int r = 0; r < roundLists.length - 1; r++) {
      final curMatches = roundLists[r];
      final nextMatches = roundLists[r + 1];

      final slotCur = size.height / curMatches.length;
      final slotNext = size.height / nextMatches.length;
      final xRight = colStride * r + cardW;
      final xLeft = colStride * (r + 1);
      final xMid = (xRight + xLeft) / 2;

      for (int i = 0; i < curMatches.length; i++) {
        final yCur = slotCur * (i + 0.5);
        final jNext = i ~/ 2;
        if (jNext >= nextMatches.length) continue;
        final yNext = slotNext * (jNext + 0.5);

        final path = Path()
          ..moveTo(xRight, yCur)
          ..lineTo(xMid, yCur)
          ..lineTo(xMid, yNext)
          ..lineTo(xLeft, yNext);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BracketConnectorPainter old) =>
      old.roundLists != roundLists;
}

class _BracketCard extends StatelessWidget {
  final Match match;
  const _BracketCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final home = match.homeTeamName ?? 'TBD';
    final away = match.awayTeamName ?? 'TBD';
    final isCompleted = match.status == 'completed';
    final isLive = match.status == 'live';
    final homeScore = match.homeScore ?? 0;
    final awayScore = match.awayScore ?? 0;
    final homeWon = isCompleted && homeScore > awayScore;
    final awayWon = isCompleted && awayScore > homeScore;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLive
              ? AppColors.danger.withAlpha(150)
              : AppColors.stroke,
        ),
      ),
      child: Column(
        children: [
          _BracketTeamRow(
            name: home,
            score: (isCompleted || isLive) ? homeScore : null,
            isWinner: homeWon,
          ),
          Divider(height: 1, thickness: 1, color: AppColors.stroke.withAlpha(80)),
          _BracketTeamRow(
            name: away,
            score: (isCompleted || isLive) ? awayScore : null,
            isWinner: awayWon,
          ),
        ],
      ),
    );
  }
}

class _BracketTeamRow extends StatelessWidget {
  final String name;
  final int? score;
  final bool isWinner;

  const _BracketTeamRow({
    required this.name,
    this.score,
    this.isWinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: AppTextStyles.labelSmall.copyWith(
                  color: isWinner
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight:
                      isWinner ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (score != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isWinner
                      ? AppColors.primarySurface
                      : AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$score',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isWinner
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.headingSmall),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Text(label,
          style: AppTextStyles.labelSmall
              .copyWith(color: AppColors.textTertiary)),
    );
  }
}

class _TeamSlot extends StatelessWidget {
  final String name;
  final CrossAxisAlignment align;
  final Color iconColor;
  final bool isIndividual;

  const _TeamSlot({
    required this.name,
    required this.align,
    required this.iconColor,
    this.isIndividual = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = align == CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppColors.stroke),
          ),
          child:
              Icon(isIndividual ? Icons.person_rounded : Icons.shield_rounded, color: iconColor, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: AppTextStyles.labelMedium,
          textAlign: isLeft ? TextAlign.left : TextAlign.right,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final bool isLive;
  final bool isCompleted;
  final String home, away;

  const _ScoreBox({
    required this.isLive,
    required this.isCompleted,
    required this.home,
    required this.away,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: (isLive || isCompleted) && home.isNotEmpty
          ? Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Text('$home – $away',
                      style: AppTextStyles.scoreLarge),
                ),
                if (isLive) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('LIVE',
                          style: AppTextStyles.labelSmall
                              .copyWith(
                                  color: AppColors.danger)),
                    ],
                  ),
                ],
              ],
            )
          : Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Text('VS',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textTertiary)),
            ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Icon(icon,
            size: 18, color: AppColors.textSecondary),
      ),
    );
  }
}

// ── Enrollment & Match Opponents Helpers ─────────────────────────────────────

class _AddParticipantButton extends ConsumerWidget {
  final Tournament tournament;
  final bool isTextButton;

  const _AddParticipantButton({
    required this.tournament,
    this.isTextButton = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIndividual = tournament.type == 'individual';
    final label = isIndividual ? 'Add Player' : 'Add Team';
    final icon = Icons.add_rounded;

    if (isTextButton) {
      return TextButton.icon(
        onPressed: () => _showAddDialog(context, ref),
        icon: Icon(icon, size: 16, color: AppColors.primary),
        label: Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
      );
    }

    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: () => _showAddDialog(context, ref),
        icon: Icon(icon, size: 16, color: Colors.black),
        label: Text(label, style: AppTextStyles.labelSmall.copyWith(color: Colors.black)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _EnrollParticipantDialog(tournament: tournament),
    );
  }
}

class _EnrollParticipantDialog extends ConsumerStatefulWidget {
  final Tournament tournament;
  const _EnrollParticipantDialog({required this.tournament});

  @override
  ConsumerState<_EnrollParticipantDialog> createState() => _EnrollParticipantDialogState();
}

class _EnrollParticipantDialogState extends ConsumerState<_EnrollParticipantDialog> {
  String? _selectedId;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final isIndividual = widget.tournament.type == 'individual';
    
    final enrolledAsync = ref.watch(tournamentTeamsProvider(widget.tournament.id));
    final allParticipantsAsync = isIndividual
        ? ref.watch(playersProvider(null))
        : ref.watch(teamsProvider(widget.tournament.sport));

    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 320,
        child: enrolledAsync.when(
          loading: () => const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
          ),
          error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
          data: (enrolled) {
            return allParticipantsAsync.when(
              loading: () => const SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
              ),
              error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
              data: (all) {
                List<dynamic> available = [];
                if (isIndividual) {
                  final enrolledCaptainIds = enrolled.map((t) => t.captainId).toSet();
                  final playersList = all as List<Player>;
                  available = playersList.where((p) => !enrolledCaptainIds.contains(p.profileId)).toList();
                } else {
                  final enrolledTeamIds = enrolled.map((t) => t.id).toSet();
                  final teamsList = all as List<Team>;
                  available = teamsList.where((t) => !enrolledTeamIds.contains(t.id)).toList();
                }

                if (available.isEmpty) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 36),
                      const SizedBox(height: 12),
                      Text(
                        isIndividual ? 'No new players to add' : 'No new teams to add',
                        style: AppTextStyles.headingSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isIndividual
                            ? 'All registered players are already enrolled.'
                            : 'All teams of this sport are enrolled.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIndividual ? 'Enroll Player' : 'Enroll Team',
                      style: AppTextStyles.headingSmall,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.stroke),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedId ?? available.first.id,
                          isExpanded: true,
                          dropdownColor: AppColors.bgCard,
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                          items: available.map((item) {
                            return DropdownMenuItem<String>(
                              value: item.id as String,
                              child: Text(
                                item.name as String,
                                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                          child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : () => _enroll(available),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 1.5),
                                )
                              : Text('Enroll', style: AppTextStyles.labelSmall.copyWith(color: Colors.black)),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _enroll(List<dynamic> available) async {
    setState(() => _isSubmitting = true);
    final isIndividual = widget.tournament.type == 'individual';
    final targetId = _selectedId ?? available.first.id;

    try {
      if (isIndividual) {
        final player = available.firstWhere((p) => p.id == targetId) as Player;
        
        final allTeams = await ref.read(teamRepositoryProvider).fetchAll(sport: widget.tournament.sport, isIndividual: true);
        Team? existingTeam;
        for (final t in allTeams) {
          if (t.captainId == player.profileId) {
            existingTeam = t;
            break;
          }
        }

        String teamId;
        if (existingTeam != null) {
          teamId = existingTeam.id;
        } else {
          final newTeam = await ref.read(teamRepositoryProvider).create({
            'name': player.name,
            'sport': widget.tournament.sport,
            'captain_id': player.profileId,
            'player_count': 1,
            'is_individual': true,
          });
          teamId = newTeam.id;
        }

        await ref.read(tournamentRepositoryProvider).joinTournament(widget.tournament.id, teamId);
      } else {
        await ref.read(tournamentRepositoryProvider).joinTournament(widget.tournament.id, targetId);
      }

      ref.invalidate(tournamentTeamsProvider(widget.tournament.id));
      ref.invalidate(tournamentDetailProvider(widget.tournament.id));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enroll failed: $e')));
      }
    }
  }
}

class _SelectOpponentsDialog extends StatefulWidget {
  final Tournament tournament;
  final List<Team> enrolled;

  const _SelectOpponentsDialog({
    required this.tournament,
    required this.enrolled,
  });

  @override
  State<_SelectOpponentsDialog> createState() => _SelectOpponentsDialogState();
}

class _SelectOpponentsDialogState extends State<_SelectOpponentsDialog> {
  String? _homeTeamId;
  String? _awayTeamId;

  @override
  void initState() {
    super.initState();
    if (widget.enrolled.isNotEmpty) {
      _homeTeamId = widget.enrolled[0].id;
      if (widget.enrolled.length > 1) {
        _awayTeamId = widget.enrolled[1].id;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIndividual = widget.tournament.type == 'individual';
    
    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Match Opponents',
              style: AppTextStyles.headingSmall,
            ),
            const SizedBox(height: 20),
            Text(
              isIndividual ? 'Player A' : 'Home Team',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.stroke),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _homeTeamId,
                  isExpanded: true,
                  dropdownColor: AppColors.bgCard,
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                  items: widget.enrolled.map((team) {
                    return DropdownMenuItem<String>(
                      value: team.id,
                      child: Text(
                        team.name,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _homeTeamId = val;
                      if (_homeTeamId == _awayTeamId) {
                        _awayTeamId = widget.enrolled.firstWhere((t) => t.id != _homeTeamId).id;
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isIndividual ? 'Player B' : 'Away Team',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.stroke),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _awayTeamId,
                  isExpanded: true,
                  dropdownColor: AppColors.bgCard,
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                  items: widget.enrolled.where((t) => t.id != _homeTeamId).map((team) {
                    return DropdownMenuItem<String>(
                      value: team.id,
                      child: Text(
                        team.name,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _awayTeamId = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _homeTeamId == null || _awayTeamId == null || _homeTeamId == _awayTeamId ? null : () {
                    final homeTeam = widget.enrolled.firstWhere((t) => t.id == _homeTeamId);
                    final awayTeam = widget.enrolled.firstWhere((t) => t.id == _awayTeamId);

                    final parentCtx = context;
                    Navigator.pop(context);
                    parentCtx.push(
                      Uri(
                        path: '/tournaments/${widget.tournament.id}/matches/new/score',
                        queryParameters: {
                          'sport': widget.tournament.sport,
                          'home': homeTeam.name,
                          'away': awayTeam.name,
                        },
                      ).toString(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Start', style: AppTextStyles.labelSmall.copyWith(color: Colors.black)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
