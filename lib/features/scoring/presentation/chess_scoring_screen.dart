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

class ChessScoringScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String playerWhite;
  final String playerBlack;

  const ChessScoringScreen({
    super.key,
    required this.matchId,
    required this.playerWhite,
    required this.playerBlack,
  });

  @override
  ConsumerState<ChessScoringScreen> createState() => _ChessScoringScreenState();
}

class _ChessScoringScreenState extends ConsumerState<ChessScoringScreen> {
  bool _isInitialized = false;

  // Clock: seconds remaining per player (default 10 minutes)
  int _whiteSeconds = 600;
  int _blackSeconds = 600;
  int _activeClock = -1; // 0=white, 1=black, -1=paused
  Timer? _timer;

  // Move log
  final List<String> _whiteMoves = [];
  final List<String> _blackMoves = [];
  final TextEditingController _moveCtrl = TextEditingController();

  bool _gameOver = false;
  String _result = '';

  @override
  void dispose() {
    _timer?.cancel();
    _moveCtrl.dispose();
    super.dispose();
  }

  void _initializeFromMatch(Match match) {
    if (_isInitialized) return;

    final meta = match.metadata;
    if (meta.containsKey('whiteSeconds')) {
      _whiteSeconds = (meta['whiteSeconds'] as int?) ?? 600;
      _blackSeconds = (meta['blackSeconds'] as int?) ?? 600;
      _activeClock = (meta['activeClock'] as int?) ?? -1;

      _whiteMoves.clear();
      _whiteMoves.addAll(List<String>.from(meta['whiteMoves'] as List));

      _blackMoves.clear();
      _blackMoves.addAll(List<String>.from(meta['blackMoves'] as List));

      _gameOver = match.status == 'completed';
      _result = (meta['result'] as String?) ?? '';

      // Compensate for elapsed time since last sync
      if (_activeClock != -1 && !_gameOver && meta.containsKey('lastSyncedAt')) {
        final lastSync = DateTime.tryParse(meta['lastSyncedAt'] as String);
        if (lastSync != null) {
          final diffSec = DateTime.now().difference(lastSync).inSeconds;
          if (diffSec > 0) {
            if (_activeClock == 0) {
              _whiteSeconds = (_whiteSeconds - diffSec).clamp(0, 99999);
              if (_whiteSeconds == 0) _flagFall(0);
            } else {
              _blackSeconds = (_blackSeconds - diffSec).clamp(0, 99999);
              if (_blackSeconds == 0) _flagFall(1);
            }
          }
        }
      }
    }

    _isInitialized = true;

    // Resume clock if it was running
    if (_activeClock != -1 && !_gameOver) {
      _startClock(_activeClock);
    }
  }

  Future<void> _syncToSupabase({bool isFinal = false}) async {
    final metadata = {
      'whiteSeconds': _whiteSeconds,
      'blackSeconds': _blackSeconds,
      'activeClock': _activeClock,
      'whiteMoves': _whiteMoves,
      'blackMoves': _blackMoves,
      'result': _result,
      'lastSyncedAt': DateTime.now().toIso8601String(),
    };
    try {
      if (isFinal) {
        await ref.read(matchScoreRepositoryProvider).finalizeMatch(
          matchId: widget.matchId,
          homeScore: _activeClock == 0 ? 0 : 1, // Simple representation
          awayScore: _activeClock == 0 ? 1 : 0,
          metadata: metadata,
        );
      } else {
        await ref.read(matchScoreRepositoryProvider).updateScore(
          matchId: widget.matchId,
          homeScore: 0,
          awayScore: 0,
          metadata: metadata,
        );
      }
    } catch (e) {
      debugPrint('Error syncing score: $e');
    }
  }

  void _startClock(int player) {
    _timer?.cancel();
    setState(() => _activeClock = player);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (player == 0) {
          if (_whiteSeconds > 0) {
            _whiteSeconds--;
          } else {
            _flagFall(0);
          }
        } else {
          if (_blackSeconds > 0) {
            _blackSeconds--;
          } else {
            _flagFall(1);
          }
        }
      });
      // Periodic sync every 15 seconds to avoid flooding API
      if (_whiteSeconds % 15 == 0) {
        _syncToSupabase();
      }
    });
  }

  void _pressClock() {
    if (_gameOver) return;
    if (_activeClock == -1) {
      _startClock(0);
      _syncToSupabase();
      return;
    }
    _addMove(_activeClock, '(move ${_moveNumber(_activeClock)})');
    _startClock(1 - _activeClock);
    _syncToSupabase();
  }

  int _moveNumber(int player) =>
      (player == 0 ? _whiteMoves.length : _blackMoves.length) + 1;

  void _addMove(int player, String notation) {
    if (notation.trim().isEmpty) return;
    setState(() {
      if (player == 0) {
        _whiteMoves.add(notation);
      } else {
        _blackMoves.add(notation);
      }
    });
    _syncToSupabase();
  }

  void _flagFall(int player) {
    _timer?.cancel();
    setState(() {
      _gameOver = true;
      _activeClock = -1;
      _result = player == 0 ? '0–1 (White flagged)' : '1–0 (Black flagged)';
    });
    _syncToSupabase(isFinal: true);
  }

  void _endGame(String result, String label) {
    _timer?.cancel();
    setState(() {
      _gameOver = true;
      _activeClock = -1;
      _result = '$result ($label)';
    });
    _syncToSupabase(isFinal: true);
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
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
                _buildTopBar(topPad),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      children: [
                        _buildClocks(),
                        const SizedBox(height: 16),
                        _buildMoveEntry(),
                        const SizedBox(height: 16),
                        _buildMoveLog(),
                        if (_gameOver) ...[
                          const SizedBox(height: 16),
                          _buildResultBanner(),
                        ],
                        if (!_gameOver) ...[
                          const SizedBox(height: 16),
                          _buildResultButtons(),
                        ],
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

  Widget _buildTopBar(double topPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [AppColors.bgCard, AppColors.bg],
        ),
      ),
      child: Row(
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
          Column(
            children: [
              Text('${widget.playerWhite} vs ${widget.playerBlack}',
                  style: AppTextStyles.headingSmall),
              Text('${_whiteMoves.length + _blackMoves.length} moves',
                  style: AppTextStyles.bodySmall),
            ],
          ),
          const Spacer(),
          _SportTag(label: '♟ Chess'),
        ],
      ),
    );
  }

  Widget _buildClocks() {
    return Row(
      children: [
        Expanded(child: _ClockCard(
          name: widget.playerWhite,
          timeDisplay: _formatTime(_whiteSeconds),
          isActive: _activeClock == 0,
          isLow: _whiteSeconds < 60,
          color: Colors.white,
          onTap: !_gameOver && _activeClock == 0 ? _pressClock : null,
        )),
        const SizedBox(width: 12),
        Expanded(child: _ClockCard(
          name: widget.playerBlack,
          timeDisplay: _formatTime(_blackSeconds),
          isActive: _activeClock == 1,
          isLow: _blackSeconds < 60,
          color: const Color(0xFF4A4A4A),
          onTap: !_gameOver && _activeClock == 1 ? _pressClock : null,
        )),
      ],
    );
  }

  Widget _buildMoveEntry() {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LOG MOVE', style: AppTextStyles.overline),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.strokeBright),
                  ),
                  child: TextField(
                    controller: _moveCtrl,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. e4, Nf3, O-O',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  final text = _moveCtrl.text.trim();
                  if (text.isNotEmpty) {
                    _addMove(_activeClock == 1 ? 1 : 0, text);
                    _moveCtrl.clear();
                  }
                },
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.black, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!_gameOver)
            GestureDetector(
              onTap: _pressClock,
              child: Container(
                width: double.infinity, height: 44,
                decoration: BoxDecoration(
                  color: _activeClock == -1 ? AppColors.primarySurface : AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _activeClock == -1 ? AppColors.glassBorder : AppColors.stroke,
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _activeClock == -1 ? Icons.play_arrow_rounded : Icons.swap_horiz_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _activeClock == -1
                          ? 'Start Game'
                          : 'Press Clock (switch turn)',
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMoveLog() {
    if (_whiteMoves.isEmpty && _blackMoves.isEmpty) return const SizedBox.shrink();
    final maxMoves = _whiteMoves.length > _blackMoves.length
        ? _whiteMoves.length : _blackMoves.length;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MOVE LOG', style: AppTextStyles.overline),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(width: 28),
              Expanded(
                child: Text('White', style: AppTextStyles.labelSmall
                    .copyWith(color: Colors.white70)),
              ),
              Expanded(
                child: Text('Black', style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textTertiary)),
              ),
            ],
          ),
          const Divider(color: AppColors.divider, height: 10),
          ...List.generate(maxMoves, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text('${i + 1}.',
                      style: AppTextStyles.bodySmall),
                ),
                Expanded(
                  child: Text(
                    i < _whiteMoves.length ? _whiteMoves[i] : '',
                    style: AppTextStyles.labelMedium.copyWith(color: Colors.white),
                  ),
                ),
                Expanded(
                  child: Text(
                    i < _blackMoves.length ? _blackMoves[i] : '',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildResultButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RESULT', style: AppTextStyles.overline),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _ResultBtn(
              label: 'White Wins',
              sub: '1 – 0',
              onTap: () => _endGame('1–0', 'White wins'),
            )),
            const SizedBox(width: 8),
            Expanded(child: _ResultBtn(
              label: 'Draw',
              sub: '½ – ½',
              color: AppColors.gold,
              onTap: () => _endGame('½–½', 'Draw'),
            )),
            const SizedBox(width: 8),
            Expanded(child: _ResultBtn(
              label: 'Black Wins',
              sub: '0 – 1',
              color: AppColors.textSecondary,
              onTap: () => _endGame('0–1', 'Black wins'),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildResultBanner() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: 36),
          const SizedBox(height: 10),
          Text('Game Over', style: AppTextStyles.headingSmall
              .copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: 4),
          Text(_result, style: AppTextStyles.headingMedium
              .copyWith(color: AppColors.primary)),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _ClockCard extends StatelessWidget {
  final String name;
  final String timeDisplay;
  final bool isActive;
  final bool isLow;
  final Color color;
  final VoidCallback? onTap;

  const _ClockCard({
    required this.name,
    required this.timeDisplay,
    required this.isActive,
    required this.isLow,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isLow ? AppColors.danger
        : isActive ? AppColors.primary : AppColors.stroke;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primarySurface : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isActive ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.stroke),
                  ),
                ),
                const SizedBox(width: 6),
                Text(name,
                    style: AppTextStyles.labelSmall,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
            const SizedBox(height: 10),
            Text(timeDisplay,
                style: AppTextStyles.scoreMedium.copyWith(
                  color: isLow ? AppColors.danger
                      : isActive ? AppColors.primary : AppColors.textSecondary,
                )),
            if (isActive) ...[
              const SizedBox(height: 6),
              Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultBtn extends StatelessWidget {
  final String label, sub;
  final Color color;
  final VoidCallback onTap;

  const _ResultBtn({
    required this.label,
    required this.sub,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        alignment: Alignment.center,
        child: Column(
          children: [
            Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
            Text(sub, style: AppTextStyles.bodySmall),
          ],
        ),
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
      color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.glassBorder),
    ),
    child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
  );
}
