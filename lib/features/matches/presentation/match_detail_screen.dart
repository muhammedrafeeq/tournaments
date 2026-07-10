import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/match.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/hyper_grid_background.dart';
import '../../../core/widgets/top_bar.dart';

class MatchDetailScreen extends ConsumerWidget {
  final String tournamentId;
  final String matchId;
  final String sport;
  final String homeTeam;
  final String awayTeam;

  const MatchDetailScreen({
    super.key,
    required this.tournamentId,
    required this.matchId,
    required this.sport,
    required this.homeTeam,
    required this.awayTeam,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchStreamProvider(matchId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: matchAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: AppColors.textTertiary, size: 40),
              const SizedBox(height: 12),
              Text('Could not load match', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(matchStreamProvider(matchId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (match) => _MatchDetailBody(
          tournamentId: tournamentId,
          match: match,
          sport: sport,
        ),
      ),
    );
  }
}

class _MatchDetailBody extends StatelessWidget {
  final String tournamentId;
  final Match match;
  final String sport;

  const _MatchDetailBody({
    required this.tournamentId,
    required this.match,
    required this.sport,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == 'live';
    final isCompleted = match.status == 'completed';
    final home = match.homeTeamName ?? homeTeam;
    final away = match.awayTeamName ?? awayTeam;

    return HyperGridBackground(
      child: Column(
        children: [
          TopBar(
            title: isLive ? 'Live Match' : isCompleted ? 'Match Result' : 'Match Preview',
            showBack: true,
            actions: [
              GestureDetector(
                onTap: () => context.push(
                  Uri(
                    path: '/tournaments/$tournamentId/matches/${match.id}/score',
                    queryParameters: {
                      'sport': sport,
                      'home': home,
                      'away': away,
                    },
                  ).toString(),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isLive ? AppColors.danger : AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isLive ? 'Score Live' : 'Enter Score',
                    style: AppTextStyles.labelSmall.copyWith(color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                _ScoreCard(match: match, home: home, away: away),
                const SizedBox(height: 16),
                _MatchInfoCard(match: match, sport: sport),
                if (match.metadata.isNotEmpty && (isLive || isCompleted)) ...[
                  const SizedBox(height: 16),
                  _SportStatsCard(
                    match: match,
                    sport: sport,
                    home: home,
                    away: away,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get homeTeam => 'Home';
  String get awayTeam => 'Away';
}

// ── Score hero card ────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final Match match;
  final String home;
  final String away;

  const _ScoreCard({required this.match, required this.home, required this.away});

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == 'live';
    final isCompleted = match.status == 'completed';
    final showScore = isLive || isCompleted;
    final homeScore = match.homeScore ?? 0;
    final awayScore = match.awayScore ?? 0;
    final homeWon = isCompleted && homeScore > awayScore;
    final awayWon = isCompleted && awayScore > homeScore;

    return GlassCardPrimary(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (isLive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.danger.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.danger.withAlpha(90)),
              ),
              child: Row(
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
                  const SizedBox(width: 6),
                  Text('LIVE',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.danger)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _TeamAvatar(name: home, won: homeWon),
                    const SizedBox(height: 10),
                    Text(home,
                        style: AppTextStyles.headingSmall.copyWith(
                          color: homeWon ? AppColors.primary : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: showScore
                    ? Column(
                        children: [
                          Text('$homeScore',
                              style: AppTextStyles.scoreLarge.copyWith(
                                fontSize: 44,
                                color: homeWon ? AppColors.primary : AppColors.textPrimary,
                              )),
                          Text('—',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: AppColors.textTertiary, height: 1.2)),
                          Text('$awayScore',
                              style: AppTextStyles.scoreLarge.copyWith(
                                fontSize: 44,
                                color: awayWon ? AppColors.primary : AppColors.textPrimary,
                              )),
                        ],
                      )
                    : Text('VS',
                        style: AppTextStyles.headingLarge
                            .copyWith(color: AppColors.textTertiary)),
              ),
              Expanded(
                child: Column(
                  children: [
                    _TeamAvatar(name: away, won: awayWon),
                    const SizedBox(height: 10),
                    Text(away,
                        style: AppTextStyles.headingSmall.copyWith(
                          color: awayWon ? AppColors.primary : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          if (isCompleted) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                homeScore == awayScore ? 'Draw' : 'Full Time',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textTertiary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamAvatar extends StatelessWidget {
  final String name;
  final bool won;
  const _TeamAvatar({required this.name, required this.won});

  Color get _color => won ? AppColors.primary : AppColors.textTertiary;

  String get _initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: _color.withAlpha(30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withAlpha(80)),
      ),
      child: Center(
        child: Text(_initials,
            style: AppTextStyles.headingMedium.copyWith(color: _color)),
      ),
    );
  }
}

// ── Match info card ────────────────────────────────────────────────────────

class _MatchInfoCard extends StatelessWidget {
  final Match match;
  final String sport;

  const _MatchInfoCard({required this.match, required this.sport});

  String _formatDateTime(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month]} ${dt.day} · $hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Match Info',
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.sports_rounded,
            label: 'Sport',
            value: sport.toUpperCase(),
          ),
          if (match.scheduledAt != null)
            _InfoRow(
              icon: Icons.schedule_rounded,
              label: 'Scheduled',
              value: _formatDateTime(match.scheduledAt!),
            ),
          _InfoRow(
            icon: Icons.flag_rounded,
            label: 'Status',
            value: match.status.toUpperCase(),
            valueColor: switch (match.status) {
              'live' => AppColors.danger,
              'completed' => AppColors.primary,
              _ => AppColors.textSecondary,
            },
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Text(value,
              style: AppTextStyles.labelSmall
                  .copyWith(color: valueColor ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}

// ── Sport-specific stats card ──────────────────────────────────────────────

class _SportStatsCard extends StatelessWidget {
  final Match match;
  final String sport;
  final String home;
  final String away;

  const _SportStatsCard({
    required this.match,
    required this.sport,
    required this.home,
    required this.away,
  });

  List<_StatRow> _buildRows() {
    final meta = match.metadata;
    final s = sport.toLowerCase();
    final rows = <_StatRow>[];

    if (s == 'football' || s == 'efootball') {
      if (meta['minute'] != null) {
        rows.add(_StatRow(label: 'Minute', center: "${meta['minute']}'"));
      }
      if (meta['homeYellow'] != null || meta['awayYellow'] != null) {
        rows.add(_StatRow(
          label: 'Yellow Cards',
          homeVal: '${meta['homeYellow'] ?? 0}',
          awayVal: '${meta['awayYellow'] ?? 0}',
        ));
      }
      if (meta['homeRed'] != null || meta['awayRed'] != null) {
        rows.add(_StatRow(
          label: 'Red Cards',
          homeVal: '${meta['homeRed'] ?? 0}',
          awayVal: '${meta['awayRed'] ?? 0}',
        ));
      }
    } else if (s == 'basketball') {
      if (meta['quarter'] != null) {
        rows.add(_StatRow(label: 'Quarter', center: 'Q${meta['quarter']}'));
      }
      for (final q in ['Q1', 'Q2', 'Q3', 'Q4']) {
        final hKey = 'home$q';
        final aKey = 'away$q';
        if (meta[hKey] != null || meta[aKey] != null) {
          rows.add(_StatRow(
            label: q,
            homeVal: '${meta[hKey] ?? 0}',
            awayVal: '${meta[aKey] ?? 0}',
          ));
        }
      }
    } else if (s == 'cricket') {
      if (meta['overs'] != null) {
        rows.add(_StatRow(label: 'Overs', center: '${meta['overs']}'));
      }
      if (meta['wickets'] != null) {
        rows.add(_StatRow(label: 'Wickets', center: '${meta['wickets']}'));
      }
    } else if (s == 'tennis') {
      final sets = meta['sets'] as List?;
      if (sets != null) {
        for (int i = 0; i < sets.length; i++) {
          final set = sets[i] as Map?;
          if (set != null) {
            rows.add(_StatRow(
              label: 'Set ${i + 1}',
              homeVal: '${set['a'] ?? 0}',
              awayVal: '${set['b'] ?? 0}',
            ));
          }
        }
      }
    } else if (s == 'badminton') {
      final games = meta['games'] as List?;
      if (games != null) {
        for (int i = 0; i < games.length; i++) {
          final game = games[i] as Map?;
          if (game != null) {
            rows.add(_StatRow(
              label: 'Game ${i + 1}',
              homeVal: '${game['a'] ?? 0}',
              awayVal: '${game['b'] ?? 0}',
            ));
          }
        }
      }
    } else {
      final rounds = meta['rounds'] as List?;
      if (rounds != null) {
        for (int i = 0; i < rounds.length; i++) {
          final r = rounds[i] as List?;
          if (r != null && r.length >= 2) {
            rows.add(_StatRow(
              label: 'Round ${i + 1}',
              homeVal: '${r[0] ?? 0}',
              awayVal: '${r[1] ?? 0}',
            ));
          }
        }
      }
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows();
    if (rows.isEmpty) return const SizedBox.shrink();

    final hasColumns = rows.any((r) => r.homeVal != null);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Match Stats',
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          if (hasColumns) ...[
            Row(
              children: [
                const Expanded(child: SizedBox()),
                Expanded(
                  child: Text(home,
                      style: AppTextStyles.overline,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: Text(away,
                      style: AppTextStyles.overline,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: r.center != null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(r.label,
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary)),
                          Text(r.center!,
                              style: AppTextStyles.labelSmall),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Text(r.label,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textSecondary)),
                          ),
                          Expanded(
                            child: Text(r.homeVal ?? '',
                                style: AppTextStyles.labelSmall,
                                textAlign: TextAlign.center),
                          ),
                          Expanded(
                            child: Text(r.awayVal ?? '',
                                style: AppTextStyles.labelSmall,
                                textAlign: TextAlign.center),
                          ),
                        ],
                      ),
              )),
        ],
      ),
    );
  }
}

class _StatRow {
  final String label;
  final String? homeVal;
  final String? awayVal;
  final String? center;

  const _StatRow({
    required this.label,
    this.homeVal,
    this.awayVal,
    this.center,
  });
}
