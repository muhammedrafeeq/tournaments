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

const _gamePoints = ['0', '15', '30', '40', 'Ad'];

class TennisScoringScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String playerA;
  final String playerB;

  const TennisScoringScreen({
    super.key,
    required this.matchId,
    required this.playerA,
    required this.playerB,
  });

  @override
  ConsumerState<TennisScoringScreen> createState() => _TennisScoringScreenState();
}

class _TennisScoringScreenState extends ConsumerState<TennisScoringScreen> {
  bool _isInitialized = false;

  // Sets: each entry is [aGames, bGames]
  final List<List<int>> _sets = [[0, 0]];

  // Current game points: 0=0, 1=15, 2=30, 3=40, 4=Ad
  int _aPoints = 0;
  int _bPoints = 0;

  // Tiebreak mode
  bool _tiebreak = false;
  int _tbA = 0;
  int _tbB = 0;

  // Server: 0=A, 1=B
  int _server = 0;

  bool _matchOver = false;
  String _winner = '';

  int get _currentSet => _sets.length - 1;

  // Sets won
  int get _aSets => _sets.where((s) => s[0] > s[1] && s[0] >= 6 && (s[0] - s[1] >= 2 || s[0] == 7)).length;
  int get _bSets => _sets.where((s) => s[1] > s[0] && s[1] >= 6 && (s[1] - s[0] >= 2 || s[1] == 7)).length;

  bool get _deuce => _aPoints >= 3 && _bPoints >= 3 && _aPoints == _bPoints;
  bool get _aAdvantage => _aPoints == 4;
  bool get _bAdvantage => _bPoints == 4;

  String get _aPointDisplay {
    if (_tiebreak) return '$_tbA';
    if (_deuce) return 'Deuce';
    if (_aAdvantage) return 'Ad';
    if (_bAdvantage) return '—';
    return _gamePoints[_aPoints];
  }

  String get _bPointDisplay {
    if (_tiebreak) return '$_tbB';
    if (_deuce) return 'Deuce';
    if (_bAdvantage) return 'Ad';
    if (_aAdvantage) return '—';
    return _gamePoints[_bPoints];
  }

  void _initializeFromMatch(Match match) {
    if (_isInitialized) return;

    final meta = match.metadata;
    if (meta.containsKey('sets')) {
      final setsList = meta['sets'] as List;
      _sets.clear();
      for (final s in setsList) {
        _sets.add(List<int>.from(s as List));
      }
      _aPoints = (meta['aPoints'] as int?) ?? 0;
      _bPoints = (meta['bPoints'] as int?) ?? 0;
      _tiebreak = (meta['tiebreak'] as bool?) ?? false;
      _tbA = (meta['tbA'] as int?) ?? 0;
      _tbB = (meta['tbB'] as int?) ?? 0;
      _server = (meta['server'] as int?) ?? 0;
      _matchOver = match.status == 'completed';
      _winner = (meta['winner'] as String?) ?? '';
    }
    _isInitialized = true;
  }

  Future<void> _syncToSupabase({bool isFinal = false}) async {
    final metadata = {
      'sets': _sets.map((s) => s).toList(),
      'aPoints': _aPoints,
      'bPoints': _bPoints,
      'tiebreak': _tiebreak,
      'tbA': _tbA,
      'tbB': _tbB,
      'server': _server,
      'winner': _winner,
    };
    try {
      if (isFinal) {
        await ref.read(matchScoreRepositoryProvider).finalizeMatch(
          matchId: widget.matchId,
          homeScore: _aSets,
          awayScore: _bSets,
          metadata: metadata,
        );
      } else {
        await ref.read(matchScoreRepositoryProvider).updateScore(
          matchId: widget.matchId,
          homeScore: _aSets,
          awayScore: _bSets,
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
      if (_tiebreak) {
        if (player == 0) _tbA++; else _tbB++;
        // Switch server every 2 points in tiebreak
        if ((_tbA + _tbB) % 2 == 1) _server = 1 - _server;
        _checkTiebreak();
      } else {
        if (player == 0) _aPoints++; else _bPoints++;
        _checkGame();
      }
    });
    _syncToSupabase(isFinal: _matchOver);
  }

  void _checkGame() {
    // Deuce → advantage
    if (_aPoints == 4 && _bPoints == 3) return; // A has advantage
    if (_bPoints == 4 && _aPoints == 3) return; // B has advantage

    // Win after advantage
    if (_aPoints == 5) { _winGame(0); return; }
    if (_bPoints == 5) { _winGame(1); return; }

    // Normal win (reached 4 before other has 3+)
    if (_aPoints == 4 && _bPoints < 3) { _winGame(0); return; }
    if (_bPoints == 4 && _aPoints < 3) { _winGame(1); return; }
  }

  void _winGame(int player) {
    _aPoints = 0;
    _bPoints = 0;
    _server = 1 - _server; // swap server each game
    _sets[_currentSet][player]++;
    _checkSet();
  }

  void _checkSet() {
    final a = _sets[_currentSet][0];
    final b = _sets[_currentSet][1];

    // Tiebreak at 6-6
    if (a == 6 && b == 6) { _tiebreak = true; _tbA = 0; _tbB = 0; return; }

    // Win set
    if ((a >= 6 && a - b >= 2) || a == 7) { _endSet(0); return; }
    if ((b >= 6 && b - a >= 2) || b == 7) { _endSet(1); return; }
  }

  void _checkTiebreak() {
    if (_tbA >= 7 && _tbA - _tbB >= 2) { _sets[_currentSet][0] = 7; _sets[_currentSet][1] = 6; _endSet(0); }
    if (_tbB >= 7 && _tbB - _tbA >= 2) { _sets[_currentSet][0] = 6; _sets[_currentSet][1] = 7; _endSet(1); }
  }

  void _endSet(int player) {
    _tiebreak = false;
    _tbA = 0; _tbB = 0;
    final newA = _aSets + (player == 0 ? 1 : 0);
    final newB = _bSets + (player == 1 ? 1 : 0);
    // Best of 3
    if (newA == 2 || newB == 2) {
      _matchOver = true;
      _winner = player == 0 ? widget.playerA : widget.playerB;
    } else {
      _sets.add([0, 0]);
    }
  }

  void _undoPoint() {
    // Simple undo: reset current game points only
    setState(() {
      if (_aPoints > 0 || _bPoints > 0) {
        if (_aPoints > _bPoints) _aPoints--;
        else _bPoints--;
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
                _buildPointButtons(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(double topPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 16),
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
              if (_tiebreak)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gold.withAlpha(80)),
                  ),
                  child: Text('TIEBREAK',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.gold)),
                )
              else
                Text('Set ${_currentSet + 1}',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
              const Spacer(),
              _SportTag(label: '🎾 Tennis'),
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
                    Text(_aPointDisplay,
                        style: AppTextStyles.scoreLarge.copyWith(
                          color: _server == 0 ? AppColors.primary : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
              _SetsWonDisplay(aSets: _aSets, bSets: _bSets),
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
                    Text(_bPointDisplay,
                        style: AppTextStyles.scoreLarge.copyWith(
                          color: _server == 1 ? AppColors.primary : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ],
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
        Text('SETS HISTORY', style: AppTextStyles.overline),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: _sets.asMap().entries.map((e) {
              final i = e.key;
              final s = e.value;
              final isCurrent = i == _currentSet;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text('Set ${i + 1}',
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
                            Text('${s[0]}', style: AppTextStyles.scoreMedium.copyWith(
                              color: s[0] > s[1] ? AppColors.primary : AppColors.textSecondary,
                            )),
                            Text('–', style: AppTextStyles.bodySmall),
                            Text('${s[1]}', style: AppTextStyles.scoreMedium.copyWith(
                              color: s[1] > s[0] ? AppColors.primary : AppColors.textSecondary,
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
      ],
    );
  }

  Widget _buildPointButtons() {
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
            onTap: _undoPoint,
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

class _SetsWonDisplay extends StatelessWidget {
  final int aSets, bSets;
  const _SetsWonDisplay({required this.aSets, required this.bSets});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Text('$aSets – $bSets',
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
      color: AppColors.primarySurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.glassBorder),
    ),
    child: Text(label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
  );
}
