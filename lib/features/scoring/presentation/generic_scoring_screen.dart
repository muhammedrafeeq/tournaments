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

class GenericScoringScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String teamA;
  final String teamB;
  final String sport;

  const GenericScoringScreen({
    super.key,
    required this.matchId,
    required this.teamA,
    required this.teamB,
    required this.sport,
  });

  @override
  ConsumerState<GenericScoringScreen> createState() => _GenericScoringScreenState();
}

class _GenericScoringScreenState extends ConsumerState<GenericScoringScreen> {
  bool _isInitialized = false;

  // Rows: each row is [aPoints, bPoints] per round
  final List<List<int?>> _rounds = [
    [null, null]
  ];

  int? _editingRow;
  int? _editingCol; // 0=A, 1=B
  final TextEditingController _ctrl = TextEditingController();
  bool _matchOver = false;

  int get _aTotal =>
      _rounds.fold(0, (s, r) => s + (r[0] ?? 0));
  int get _bTotal =>
      _rounds.fold(0, (s, r) => s + (r[1] ?? 0));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _initializeFromMatch(Match match) {
    if (_isInitialized) return;

    final meta = match.metadata;
    if (meta.containsKey('rounds')) {
      final roundsList = meta['rounds'] as List;
      _rounds.clear();
      for (final r in roundsList) {
        final pair = r as List;
        _rounds.add([
          pair[0] as int?,
          pair[1] as int?,
        ]);
      }
      _matchOver = match.status == 'completed';
    }
    _isInitialized = true;
  }

  Future<void> _syncToSupabase({bool isFinal = false}) async {
    final metadata = {
      'rounds': _rounds.map((r) => [r[0], r[1]]).toList(),
    };
    try {
      if (isFinal) {
        await ref.read(matchScoreRepositoryProvider).finalizeMatch(
          matchId: widget.matchId,
          homeScore: _aTotal,
          awayScore: _bTotal,
          metadata: metadata,
        );
      } else {
        await ref.read(matchScoreRepositoryProvider).updateScore(
          matchId: widget.matchId,
          homeScore: _aTotal,
          awayScore: _bTotal,
          metadata: metadata,
        );
      }
    } catch (e) {
      debugPrint('Error syncing score: $e');
    }
  }

  void _startEdit(int row, int col, int? current) {
    if (_matchOver) return;
    setState(() {
      _editingRow = row;
      _editingCol = col;
      _ctrl.text = current?.toString() ?? '';
    });
  }

  void _commitEdit() {
    if (_editingRow == null || _editingCol == null) return;
    final val = int.tryParse(_ctrl.text.trim());
    setState(() {
      _rounds[_editingRow!][_editingCol!] = val;
      _editingRow = null;
      _editingCol = null;
      _ctrl.clear();
    });
    _syncToSupabase();
  }

  void _addRound() {
    if (_matchOver) return;
    setState(() => _rounds.add([null, null]));
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
                _buildBottomBar(),
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
              _SportTag(label: widget.sport.toUpperCase()),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(widget.teamA,
                        style: AppTextStyles.headingSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('$_aTotal',
                        style: AppTextStyles.scoreLarge.copyWith(
                          color: _aTotal > _bTotal ? AppColors.primary : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Text('TOTAL', style: AppTextStyles.overline),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(widget.teamB,
                        style: AppTextStyles.headingSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('$_bTotal',
                        style: AppTextStyles.scoreLarge.copyWith(
                          color: _bTotal > _aTotal ? AppColors.primary : AppColors.textPrimary,
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text('Round', style: AppTextStyles.overline),
                    ),
                    Expanded(
                      child: Text(widget.teamA,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.overline),
                    ),
                    Expanded(
                      child: Text(widget.teamB,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.overline),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              // Rows
              ..._rounds.asMap().entries.map((e) {
                final i = e.key;
                final r = e.value;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text('Round ${i + 1}',
                                style: AppTextStyles.bodySmall),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _startEdit(i, 0, r[0]),
                              child: _ScoreCell(
                                value: r[0],
                                isEditing: _editingRow == i && _editingCol == 0,
                                controller: _ctrl,
                                onSubmit: _commitEdit,
                                isLeading: (r[0] ?? 0) > (r[1] ?? 0),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _startEdit(i, 1, r[1]),
                              child: _ScoreCell(
                                value: r[1],
                                isEditing: _editingRow == i && _editingCol == 1,
                                controller: _ctrl,
                                onSubmit: _commitEdit,
                                isLeading: (r[1] ?? 0) > (r[0] ?? 0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: i * 40), duration: 250.ms),
                    if (i < _rounds.length - 1)
                      const Divider(height: 1, color: AppColors.divider),
                  ],
                );
              }),
              const Divider(height: 1, color: AppColors.divider),
              // Total row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 60,
                      child: Text('Total', style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                    ),
                    Expanded(
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: _aTotal > _bTotal ? AppColors.primarySurface : AppColors.bgElevated,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text('$_aTotal',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: _aTotal > _bTotal ? AppColors.primary : AppColors.textPrimary,
                            )),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: _bTotal > _aTotal ? AppColors.primarySurface : AppColors.bgElevated,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text('$_bTotal',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: _bTotal > _aTotal ? AppColors.primary : AppColors.textPrimary,
                            )),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!_matchOver)
          GestureDetector(
            onTap: _addRound,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.stroke, style: BorderStyle.solid),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Add Round',
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    if (_matchOver) {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          border: Border(top: BorderSide(color: AppColors.stroke)),
        ),
        alignment: Alignment.center,
        child: Text('Match Ended', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
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

class _ScoreCell extends StatelessWidget {
  final int? value;
  final bool isEditing;
  final bool isLeading;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const _ScoreCell({
    required this.value,
    required this.isEditing,
    required this.controller,
    required this.onSubmit,
    this.isLeading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return Container(
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary),
        ),
        child: TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
          onSubmitted: (_) => onSubmit(),
        ),
      );
    }
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isLeading ? AppColors.primarySurface : AppColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLeading ? AppColors.glassBorder : AppColors.stroke,
        ),
      ),
      alignment: Alignment.center,
      child: value == null
          ? const Icon(Icons.edit_rounded, size: 14, color: AppColors.textTertiary)
          : Text('$value',
               style: AppTextStyles.labelLarge.copyWith(
                 color: isLeading ? AppColors.primary : AppColors.textPrimary,
               )),
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
