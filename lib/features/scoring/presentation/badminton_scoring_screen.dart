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

class BadmintonScoringScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String playerA;
  final String playerB;

  const BadmintonScoringScreen({
    super.key,
    required this.matchId,
    required this.playerA,
    required this.playerB,
  });

  @override
  ConsumerState<BadmintonScoringScreen> createState() => _BadmintonScoringScreenState();
}

class _BadmintonScoringScreenState extends ConsumerState<BadmintonScoringScreen> {
  bool _isInitialized = false;

  // Best of 3 games, 21 pts each (win by 2, cap 30)
  final List<List<int>> _games = [[0, 0]];
  int _server = 0; // 0=A, 1=B

  bool _matchOver = false;
  String _winner = '';

  int get _currentGame => _games.length - 1;
  int get _aScore => _games[_currentGame][0];
  int get _bScore => _games[_currentGame][1];
  int get _aGamesWon => _games.where((g) => _isGameWon(g, 0)).length;
  int get _bGamesWon => _games.where((g) => _isGameWon(g, 1)).length;

  bool _isGameWon(List<int> g, int p) {
    final me = g[p], opp = g[1 - p];
    return (me >= 21 && me - opp >= 2) || me >= 30;
  }

  void _initializeFromMatch(Match match) {
    if (_isInitialized) return;

    final meta = match.metadata;
    if (meta.containsKey('games')) {
      final gamesList = meta['games'] as List;
      _games.clear();
      for (final g in gamesList) {
        _games.add(List<int>.from(g as List));
      }
      _server = (meta['server'] as int?) ?? 0;
      _matchOver = match.status == 'completed';
      _winner = (meta['winner'] as String?) ?? '';
    }

    _isInitialized = true;
  }

  Future<void> _syncToSupabase({bool isFinal = false}) async {
    final metadata = {
      'games': _games.map((g) => g).toList(),
      'server': _server,
      'winner': _winner,
    };
    try {
      if (isFinal) {
        await ref.read(matchScoreRepositoryProvider).finalizeMatch(
          matchId: widget.matchId,
          homeScore: _aGamesWon,
          awayScore: _bGamesWon,
          metadata: metadata,
        );
      } else {
        await ref.read(matchScoreRepositoryProvider).updateScore(
          matchId: widget.matchId,
          homeScore: _aGamesWon,
          awayScore: _bGamesWon,
          metadata: metadata,
        );
      }
    } catch (e) {
      debugPrint('Error syncing score: $e');
    }
  }

  void _point(int player) {
    if (_matchOver) return;
    setState(() {
      _games[_currentGame][player]++;
      _server = player; // server = last point winner
      _checkGame();
    });
    _syncToSupabase(isFinal: _matchOver);
  }

  void _checkGame() {
    final a = _aScore, b = _bScore;
    int? winner;
    if ((a >= 21 && a - b >= 2) || a >= 30) winner = 0;
    if ((b >= 21 && b - a >= 2) || b >= 30) winner = 1;
    if (winner == null) return;

    final newA = _aGamesWon;
    final newB = _bGamesWon;

    if (newA == 2 || newB == 2) {
      _matchOver = true;
      _winner = winner == 0 ? widget.playerA : widget.playerB;
    } else {
      _games.add([0, 0]);
    }
  }

  void _undo() {
    setState(() {
      if (_aScore > 0 || _bScore > 0) {
        if (_aScore > _bScore) {
          _games[_currentGame][0]--;
        } else {
          _games[_currentGame][1]--;
        }
      } else if (_currentGame > 0) {
        // Rollback to previous game
        _games.removeLast();
        _matchOver = false;
        _winner = '';
      }
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
                Expanded(child: _buildBody()),
                _buildButtons(),
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
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
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
                    color: AppColors.bgCard, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: AppColors.textSecondary),
                ),
              ),
              const Spacer(),
              Text('Game ${_currentGame + 1}',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
              const Spacer(),
              _SportTag(label: '🏸 Badminton'),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_server == 0) const Icon(Icons.circle, size: 10, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(widget.playerA,
                            style: AppTextStyles.headingSmall, textAlign: TextAlign.center),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('$_aScore',
                        style: AppTextStyles.scoreLarge.copyWith(
                          color: _aScore > _bScore ? AppColors.primary : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
              _GamesWonDisplay(aGames: _aGamesWon, bGames: _bGamesWon),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.playerB,
                            style: AppTextStyles.headingSmall, textAlign: TextAlign.center),
                        const SizedBox(width: 4),
                        if (_server == 1) const Icon(Icons.circle, size: 10, color: AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('$_bScore',
                        style: AppTextStyles.scoreLarge.copyWith(
                          color: _bScore > _aScore ? AppColors.primary : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (_aScore + _bScore) / 42,
            backgroundColor: AppColors.stroke,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_matchOver) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                color: AppColors.primarySurface, shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 16),
            Text('Match Over', style: AppTextStyles.headingSmall.copyWith(color: AppColors.textTertiary)),
            const SizedBox(height: 6),
            Text(_winner, style: AppTextStyles.headingLarge.copyWith(color: AppColors.primary)),
            Text('wins the match', style: AppTextStyles.bodyMedium),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        Text('GAME SCORES', style: AppTextStyles.overline),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: _games.asMap().entries.map((e) {
              final i = e.key;
              final g = e.value;
              final isCurrent = i == _currentGame;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text('Game ${i + 1}',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: isCurrent ? AppColors.primary : AppColors.textTertiary)),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isCurrent ? AppColors.primarySurface : AppColors.bgElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrent ? AppColors.glassBorder : AppColors.stroke,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text('${g[0]}', style: AppTextStyles.scoreMedium.copyWith(
                              color: g[0] > g[1] ? AppColors.primary : AppColors.textSecondary,
                            )),
                            Text('–', style: AppTextStyles.bodySmall),
                            Text('${g[1]}', style: AppTextStyles.scoreMedium.copyWith(
                              color: g[1] > g[0] ? AppColors.primary : AppColors.textSecondary,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Text('TARGET: First to 21 (win by 2 · max 30)',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildButtons() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.stroke)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _point(0),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('+1 Point', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
                    Text(widget.playerA, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _undo,
            child: Container(
              width: 52, height: 64,
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.stroke),
              ),
              child: const Icon(Icons.undo_rounded, color: AppColors.textTertiary, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _point(1),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.stroke),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('+1 Point', style: AppTextStyles.labelLarge),
                    Text(widget.playerB, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GamesWonDisplay extends StatelessWidget {
  final int aGames, bGames;
  const _GamesWonDisplay({required this.aGames, required this.bGames});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Text('$aGames – $bGames',
          style: AppTextStyles.headingSmall.copyWith(color: AppColors.textTertiary)),
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
      color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.glassBorder),
    ),
    child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
  );
}
