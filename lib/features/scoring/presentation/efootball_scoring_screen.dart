import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/models/match.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/hyper_grid_background.dart';

class EFootballScoringScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String homeTeam;
  final String awayTeam;

  const EFootballScoringScreen({
    super.key,
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
  });

  @override
  ConsumerState<EFootballScoringScreen> createState() => _EFootballScoringScreenState();
}

class _EFootballScoringScreenState extends ConsumerState<EFootballScoringScreen> {
  bool _isInitialized = false;
  int _homeScore = 0;
  int _awayScore = 0;
  bool _matchOver = false;

  void _initializeFromMatch(Match match) {
    if (_isInitialized) return;
    _homeScore = match.homeScore ?? 0;
    _awayScore = match.awayScore ?? 0;
    _matchOver = match.status == 'completed';
    _isInitialized = true;
  }

  Future<void> _syncToSupabase({bool isFinal = false}) async {
    try {
      if (isFinal) {
        await ref.read(matchScoreRepositoryProvider).finalizeMatch(
          matchId: widget.matchId,
          homeScore: _homeScore,
          awayScore: _awayScore,
          metadata: const {},
        );
      } else {
        await ref.read(matchScoreRepositoryProvider).updateScore(
          matchId: widget.matchId,
          homeScore: _homeScore,
          awayScore: _awayScore,
          metadata: const {},
        );
      }
    } catch (e) {
      debugPrint('Error syncing score: $e');
    }
  }

  void _adjustScore(bool isHome, bool increment) {
    if (_matchOver) return;
    setState(() {
      if (isHome) {
        if (increment) _homeScore++;
        else if (_homeScore > 0) _homeScore--;
      } else {
        if (increment) _awayScore++;
        else if (_awayScore > 0) _awayScore--;
      }
    });
    _syncToSupabase();
  }

  void _finalizeMatch() {
    setState(() {
      _matchOver = true;
    });
    _syncToSupabase(isFinal: true);
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
                _buildActionBar(),
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
              Text(_matchOver ? 'Match Ended' : 'Live Score',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
              const Spacer(),
              _SportTag(label: '🎮 eFootball'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            children: [
              Row(
                children: [
                  // Home Team
                  Expanded(
                    child: Column(
                      children: [
                        Text(widget.homeTeam,
                            style: AppTextStyles.headingMedium, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        Text('$_homeScore', style: AppTextStyles.scoreLarge),
                        const SizedBox(height: 24),
                        if (!_matchOver)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _CircleBtn(icon: Icons.remove, onTap: () => _adjustScore(true, false)),
                              const SizedBox(width: 14),
                              _CircleBtn(icon: Icons.add, onTap: () => _adjustScore(true, true), isPrimary: true),
                            ],
                          ),
                      ],
                    ),
                  ),
                  // Separator
                  Container(
                    height: 100,
                    width: 1,
                    color: AppColors.divider,
                  ),
                  // Away Team
                  Expanded(
                    child: Column(
                      children: [
                        Text(widget.awayTeam,
                            style: AppTextStyles.headingMedium, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        Text('$_awayScore', style: AppTextStyles.scoreLarge),
                        const SizedBox(height: 24),
                        if (!_matchOver)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _CircleBtn(icon: Icons.remove, onTap: () => _adjustScore(false, false)),
                              const SizedBox(width: 14),
                              _CircleBtn(icon: Icons.add, onTap: () => _adjustScore(false, true), isPrimary: true),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    if (_matchOver) {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          border: Border(top: BorderSide(color: AppColors.stroke)),
        ),
        alignment: Alignment.center,
        child: Text('Final Score: $_homeScore – $_awayScore', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.stroke)),
      ),
      child: GestureDetector(
        onTap: _finalizeMatch,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text('Finalize Match',
              style: AppTextStyles.labelLarge.copyWith(color: Colors.black)),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _CircleBtn({required this.icon, required this.onTap, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primarySurface : AppColors.bgElevated,
          shape: BoxShape.circle,
          border: Border.all(color: isPrimary ? AppColors.glassBorder : AppColors.stroke),
        ),
        child: Icon(icon, size: 20, color: isPrimary ? AppColors.primary : AppColors.textSecondary),
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
