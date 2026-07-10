import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/models/match.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/hyper_grid_background.dart';

class _BSEvent {
  final String team;
  final String description;
  final int quarter;
  final int points;
  const _BSEvent({required this.team, required this.description, required this.quarter, this.points = 0});
}

class _Player {
  final String name;
  int points;
  int fouls;
  _Player(this.name) : points = 0, fouls = 0;
}

class BasketballScoringScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String homeTeam;
  final String awayTeam;

  const BasketballScoringScreen({
    super.key,
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
  });

  @override
  ConsumerState<BasketballScoringScreen> createState() => _BasketballScoringScreenState();
}

class _BasketballScoringScreenState extends ConsumerState<BasketballScoringScreen> {
  bool _isInitialized = false;
  int _homeScore = 0;
  int _awayScore = 0;
  int _quarter = 1;
  final List<int> _homeByQuarter = [0];
  final List<int> _awayByQuarter = [0];
  final List<_BSEvent> _events = [];
  final List<_Player> _homePlayers = List.generate(5, (i) => _Player('Player ${i + 1}'));
  final List<_Player> _awayPlayers = List.generate(5, (i) => _Player('Player ${i + 1}'));

  void _initializeFromMatch(Match match) {
    if (_isInitialized) return;
    _homeScore = match.homeScore ?? 0;
    _awayScore = match.awayScore ?? 0;

    final meta = match.metadata;
    if (meta.containsKey('quarter')) {
      _quarter = (meta['quarter'] as int?) ?? 1;

      _homeByQuarter.clear();
      _homeByQuarter.addAll(List<int>.from(meta['homeByQuarter'] as List));

      _awayByQuarter.clear();
      _awayByQuarter.addAll(List<int>.from(meta['awayByQuarter'] as List));

      _events.clear();
      final evList = meta['events'] as List;
      for (final ev in evList) {
        final evMap = ev as Map<String, dynamic>;
        _events.add(_BSEvent(
          team: evMap['team'] as String,
          description: evMap['description'] as String,
          quarter: evMap['quarter'] as int,
          points: evMap['points'] as int? ?? 0,
        ));
      }

      _homePlayers.clear();
      final hpList = meta['homePlayers'] as List;
      for (final hp in hpList) {
        final pMap = hp as Map<String, dynamic>;
        final p = _Player(pMap['name'] as String);
        p.points = pMap['points'] as int? ?? 0;
        p.fouls = pMap['fouls'] as int? ?? 0;
        _homePlayers.add(p);
      }

      _awayPlayers.clear();
      final apList = meta['awayPlayers'] as List;
      for (final ap in apList) {
        final pMap = ap as Map<String, dynamic>;
        final p = _Player(pMap['name'] as String);
        p.points = pMap['points'] as int? ?? 0;
        p.fouls = pMap['fouls'] as int? ?? 0;
        _awayPlayers.add(p);
      }
    }
    _isInitialized = true;
  }

  Future<void> _syncToSupabase({bool isFinal = false}) async {
    final metadata = {
      'quarter': _quarter,
      'homeByQuarter': _homeByQuarter,
      'awayByQuarter': _awayByQuarter,
      'events': _events.map((e) => {
        'team': e.team,
        'description': e.description,
        'quarter': e.quarter,
        'points': e.points,
      }).toList(),
      'homePlayers': _homePlayers.map((p) => {
        'name': p.name,
        'points': p.points,
        'fouls': p.fouls,
      }).toList(),
      'awayPlayers': _awayPlayers.map((p) => {
        'name': p.name,
        'points': p.points,
        'fouls': p.fouls,
      }).toList(),
    };
    try {
      if (isFinal) {
        await ref.read(matchScoreRepositoryProvider).finalizeMatch(
          matchId: widget.matchId,
          homeScore: _homeScore,
          awayScore: _awayScore,
          metadata: metadata,
        );
      } else {
        await ref.read(matchScoreRepositoryProvider).updateScore(
          matchId: widget.matchId,
          homeScore: _homeScore,
          awayScore: _awayScore,
          metadata: metadata,
        );
      }
    } catch (e) {
      debugPrint('Error syncing score: $e');
    }
  }

  void _score(String team, int pts) {
    setState(() {
      if (team == widget.homeTeam) {
        _homeScore += pts;
        _homeByQuarter[_quarter - 1] += pts;
      } else {
        _awayScore += pts;
        _awayByQuarter[_quarter - 1] += pts;
      }
      _events.insert(0, _BSEvent(
        team: team,
        description: '+$pts Point${pts > 1 ? 's' : ''}',
        quarter: _quarter,
        points: pts,
      ));
    });
    _syncToSupabase();
  }

  void _undo() {
    if (_events.isEmpty) return;
    setState(() {
      final last = _events.removeAt(0);
      if (last.team == widget.homeTeam) {
        _homeScore -= last.points;
        _homeByQuarter[last.quarter - 1] -= last.points;
      } else {
        _awayScore -= last.points;
        _awayByQuarter[last.quarter - 1] -= last.points;
      }
    });
    _syncToSupabase();
  }

  void _nextQuarter() {
    setState(() {
      if (_quarter < 4) {
        _quarter++;
        _homeByQuarter.add(0);
        _awayByQuarter.add(0);
        _syncToSupabase();
      } else {
        _finalizeMatch();
      }
    });
  }

  void _finalizeMatch() {
    _syncToSupabase(isFinal: true);
    Navigator.pop(context);
  }

  void _foul(String team, int index) {
    setState(() {
      final p = team == widget.homeTeam ? _homePlayers[index] : _awayPlayers[index];
      p.fouls++;
      _events.insert(0, _BSEvent(
        team: team,
        description: 'Foul — ${p.name}',
        quarter: _quarter,
      ));
    });
    _syncToSupabase();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final matchAsync = ref.watch(matchStreamProvider(widget.matchId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: HyperGridBackground(
        child: matchAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
          ),
          error: (err, st) => Center(
            child: Text('Could not load match: $err', style: AppTextStyles.bodyMedium),
          ),
          data: (match) {
            _initializeFromMatch(match);
            return Column(
              children: [
                _buildHeader(topPad),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildScoreButtons(),
                        const SizedBox(height: 16),
                        _buildQuarterBox(),
                        const SizedBox(height: 16),
                        _buildFoulTracker(),
                        const SizedBox(height: 16),
                        _buildEventLog(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(double topPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bgCard, AppColors.bg],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: AppColors.textSecondary),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Text('Q$_quarter',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
              ),
              const Spacer(),
              _SportTag(label: '🏀 Basketball'),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(widget.homeTeam,
                        style: AppTextStyles.headingSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('$_homeScore',
                        style: AppTextStyles.scoreLarge, textAlign: TextAlign.center),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Text('VS', style: AppTextStyles.headingSmall
                    .copyWith(color: AppColors.textTertiary)),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(widget.awayTeam,
                        style: AppTextStyles.headingSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('$_awayScore',
                        style: AppTextStyles.scoreLarge, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _undo,
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.stroke),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.undo_rounded, size: 16, color: AppColors.textTertiary),
                        const SizedBox(width: 6),
                        Text('Undo', style: AppTextStyles.labelSmall),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _nextQuarter,
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.skip_next_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(_quarter < 4 ? 'Next Quarter' : 'End Game',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreButtons() {
    return Row(
      children: [
        Expanded(child: _TeamScorer(team: widget.homeTeam, onScore: (pts) => _score(widget.homeTeam, pts))),
        const SizedBox(width: 12),
        Expanded(child: _TeamScorer(team: widget.awayTeam, onScore: (pts) => _score(widget.awayTeam, pts))),
      ],
    );
  }

  Widget _buildQuarterBox() {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QUARTER SCORES', style: AppTextStyles.overline),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text('Team', style: AppTextStyles.labelSmall),
              ),
              for (int q = 1; q <= _quarter; q++)
                Expanded(
                  child: Text('Q$q',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall),
                ),
              Expanded(
                child: Text('Total',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
              ),
            ],
          ),
          const Divider(color: AppColors.divider, height: 12),
          _QuarterRow(
            team: widget.homeTeam,
            byQ: _homeByQuarter,
            total: _homeScore,
            quarters: _quarter,
          ),
          const SizedBox(height: 6),
          _QuarterRow(
            team: widget.awayTeam,
            byQ: _awayByQuarter,
            total: _awayScore,
            quarters: _quarter,
          ),
        ],
      ),
    );
  }

  Widget _buildFoulTracker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FOUL TRACKER', style: AppTextStyles.overline),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _FoulList(
              team: widget.homeTeam,
              players: _homePlayers,
              onFoul: (i) => _foul(widget.homeTeam, i),
            )),
            const SizedBox(width: 12),
            Expanded(child: _FoulList(
              team: widget.awayTeam,
              players: _awayPlayers,
              onFoul: (i) => _foul(widget.awayTeam, i),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildEventLog() {
    if (_events.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EVENT LOG', style: AppTextStyles.overline),
        const SizedBox(height: 8),
        ..._events.take(8).map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Q${e.quarter}', style: AppTextStyles.bodySmall),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(e.description, style: AppTextStyles.labelMedium)),
                Text(e.team, style: AppTextStyles.bodySmall),
              ],
            ),
          ).animate().fadeIn(duration: 250.ms),
        )),
      ],
    );
  }
}

class _TeamScorer extends StatelessWidget {
  final String team;
  final void Function(int) onScore;
  const _TeamScorer({required this.team, required this.onScore});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Text(team, style: AppTextStyles.labelMedium, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(
            children: [1, 2, 3].map((pts) => Expanded(
              child: GestureDetector(
                onTap: () => onScore(pts),
                child: Container(
                  height: 48,
                  margin: EdgeInsets.only(right: pts < 3 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text('+$pts',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.primary)),
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _QuarterRow extends StatelessWidget {
  final String team;
  final List<int> byQ;
  final int total;
  final int quarters;
  const _QuarterRow({required this.team, required this.byQ, required this.total, required this.quarters});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(team,
              style: AppTextStyles.bodySmall,
              overflow: TextOverflow.ellipsis),
        ),
        for (int q = 0; q < quarters; q++)
          Expanded(
            child: Text('${byQ[q]}',
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall),
          ),
        Expanded(
          child: Text('$total',
              textAlign: TextAlign.center,
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.primary)),
        ),
      ],
    );
  }
}

class _FoulList extends StatelessWidget {
  final String team;
  final List<_Player> players;
  final void Function(int) onFoul;
  const _FoulList({required this.team, required this.players, required this.onFoul});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(team, style: AppTextStyles.labelSmall),
          const SizedBox(height: 10),
          ...players.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: Text(e.value.name, style: AppTextStyles.bodySmall)),
                GestureDetector(
                  onTap: () => onFoul(e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: e.value.fouls >= 5
                          ? AppColors.danger.withAlpha(30)
                          : AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: e.value.fouls >= 5 ? AppColors.danger : AppColors.stroke,
                      ),
                    ),
                    child: Text(
                      e.value.fouls >= 5 ? 'OUT' : '${e.value.fouls}F',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: e.value.fouls >= 5 ? AppColors.danger : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _SportTag extends StatelessWidget {
  final String label;
  const _SportTag({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.primarySurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.glassBorder),
    ),
    child: Text(label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
  );
}
