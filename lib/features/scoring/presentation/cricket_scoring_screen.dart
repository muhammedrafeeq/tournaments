import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/models/match.dart';
import '../../../core/models/player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/hyper_grid_background.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

enum BallType { dot, runs, four, six, wide, noBall, legBye, bye, wicket }

class BallEvent {
  final BallType type;
  final int runs;
  const BallEvent(this.type, {this.runs = 0});

  bool get isLegal =>
      type != BallType.wide && type != BallType.noBall;

  String get display {
    switch (type) {
      case BallType.dot:   return '·';
      case BallType.four:  return '4';
      case BallType.six:   return '6';
      case BallType.wide:  return 'Wd';
      case BallType.noBall: return 'Nb';
      case BallType.legBye: return 'Lb';
      case BallType.bye:   return 'B';
      case BallType.wicket: return 'W';
      case BallType.runs:  return '$runs';
    }
  }

  Color get color {
    switch (type) {
      case BallType.four:   return const Color(0xFF00B0FF);
      case BallType.six:    return AppColors.gold;
      case BallType.wicket: return AppColors.danger;
      case BallType.wide:
      case BallType.noBall: return AppColors.warning;
      case BallType.dot:    return AppColors.textTertiary;
      default:              return AppColors.textSecondary;
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'runs': runs,
      };

  factory BallEvent.fromJson(Map<String, dynamic> json) => BallEvent(
        BallType.values.firstWhere(
          (val) => val.name == json['type'],
          orElse: () => BallType.dot,
        ),
        runs: json['runs'] as int? ?? 0,
      );
}

class BatterState {
  String name;
  int runs, balls, fours, sixes;
  bool isOut;
  String dismissal;
  bool onStrike;

  BatterState({
    required this.name,
    this.runs = 0,
    this.balls = 0,
    this.fours = 0,
    this.sixes = 0,
    this.isOut = false,
    this.dismissal = '',
    this.onStrike = false,
  });

  double get strikeRate =>
      balls == 0 ? 0.0 : (runs / balls) * 100;

  Map<String, dynamic> toJson() => {
        'name': name,
        'runs': runs,
        'balls': balls,
        'fours': fours,
        'sixes': sixes,
        'isOut': isOut,
        'dismissal': dismissal,
        'onStrike': onStrike,
      };

  factory BatterState.fromJson(Map<String, dynamic> json) => BatterState(
        name: json['name'] as String,
        runs: json['runs'] as int? ?? 0,
        balls: json['balls'] as int? ?? 0,
        fours: json['fours'] as int? ?? 0,
        sixes: json['sixes'] as int? ?? 0,
        isOut: json['isOut'] as bool? ?? false,
        dismissal: json['dismissal'] as String? ?? '',
        onStrike: json['onStrike'] as bool? ?? false,
      );
}

class BowlerState {
  String name;
  int completedOvers, balls, runsConceded, wickets, maidens;

  BowlerState({
    required this.name,
    this.completedOvers = 0,
    this.balls = 0,
    this.runsConceded = 0,
    this.wickets = 0,
    this.maidens = 0,
  });

  String get oversDisplay => '$completedOvers.${balls % 6}';
  double get economy =>
      completedOvers == 0 && balls == 0 ? 0.0 : runsConceded / (completedOvers + (balls / 6));

  Map<String, dynamic> toJson() => {
        'name': name,
        'completedOvers': completedOvers,
        'balls': balls,
        'runsConceded': runsConceded,
        'wickets': wickets,
        'maidens': maidens,
      };

  factory BowlerState.fromJson(Map<String, dynamic> json) => BowlerState(
        name: json['name'] as String,
        completedOvers: json['completedOvers'] as int? ?? 0,
        balls: json['balls'] as int? ?? 0,
        runsConceded: json['runsConceded'] as int? ?? 0,
        wickets: json['wickets'] as int? ?? 0,
        maidens: json['maidens'] as int? ?? 0,
      );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class CricketScoringScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String homeTeam;
  final String awayTeam;

  const CricketScoringScreen({
    super.key,
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
  });

  @override
  ConsumerState<CricketScoringScreen> createState() => _CricketScoringScreenState();
}

class _CricketScoringScreenState extends ConsumerState<CricketScoringScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isInitialized = false;

  // Innings
  int _innings = 1;
  int _totalRuns = 0;
  int _wickets = 0;
  int _legalBalls = 0;
  int _target = 0;

  // Extras
  int _extrasWide = 0, _extrasNB = 0, _extrasLB = 0, _extrasB = 0;

  // Current over
  final List<BallEvent> _currentOverBalls = [];
  final List<List<BallEvent>> _completedOvers = [];

  // Batters
  late BatterState _batter1;
  late BatterState _batter2;
  final List<BatterState> _allBatters = [];
  int _nextBatterNumber = 3;

  // Bowler
  late BowlerState _currentBowler;
  final List<BowlerState> _allBowlers = [];

  // Fall of wickets
  final List<String> _fowLog = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Default initial states
    _batter1 = BatterState(name: 'Opening Batter 1', onStrike: true);
    _batter2 = BatterState(name: 'Opening Batter 2');
    _allBatters.addAll([_batter1, _batter2]);
    _currentBowler = BowlerState(name: 'Opening Bowler');
    _allBowlers.add(_currentBowler);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int get _completedOversCount => _legalBalls ~/ 6;
  int get _ballsInCurrentOver => _legalBalls % 6;

  String get _oversDisplay => '$_completedOversCount.$_ballsInCurrentOver';

  String get _runRate => _legalBalls == 0
      ? '0.00'
      : (_totalRuns / (_legalBalls / 6)).toStringAsFixed(2);

  int get _totalExtras => _extrasWide + _extrasNB + _extrasLB + _extrasB;

  // --- Supabase Synchronization ---

  void _initializeFromMatch(Match match) {
    if (_isInitialized) return;
    
    final meta = match.metadata;
    if (meta.containsKey('innings')) {
      _innings = (meta['innings'] as int?) ?? 1;
      _totalRuns = (meta['totalRuns'] as int?) ?? 0;
      _wickets = (meta['wickets'] as int?) ?? 0;
      _legalBalls = (meta['legalBalls'] as int?) ?? 0;
      _target = (meta['target'] as int?) ?? 0;
      _extrasWide = (meta['extrasWide'] as int?) ?? 0;
      _extrasNB = (meta['extrasNB'] as int?) ?? 0;
      _extrasLB = (meta['extrasLB'] as int?) ?? 0;
      _extrasB = (meta['extrasB'] as int?) ?? 0;

      // Restore over balls
      if (meta['currentOverBalls'] != null) {
        _currentOverBalls.clear();
        _currentOverBalls.addAll((meta['currentOverBalls'] as List)
            .map((b) => BallEvent.fromJson(b as Map<String, dynamic>)));
      }

      // Restore completed overs
      if (meta['completedOvers'] != null) {
        _completedOvers.clear();
        final ovs = meta['completedOvers'] as List;
        for (final ov in ovs) {
          _completedOvers.add((ov as List)
              .map((b) => BallEvent.fromJson(b as Map<String, dynamic>))
              .toList());
        }
      }

      // Restore batters
      if (meta['allBatters'] != null) {
        _allBatters.clear();
        _allBatters.addAll((meta['allBatters'] as List)
            .map((b) => BatterState.fromJson(b as Map<String, dynamic>)));
        
        // Match active batters on strike
        final onStrikeList = _allBatters.where((b) => b.onStrike && !b.isOut).toList();
        final offStrikeList = _allBatters.where((b) => !b.onStrike && !b.isOut).toList();

        if (onStrikeList.isNotEmpty) {
          _batter1 = onStrikeList.first;
        } else {
          _batter1 = _allBatters.first;
        }

        if (offStrikeList.isNotEmpty) {
          _batter2 = offStrikeList.first;
        } else if (_allBatters.length > 1) {
          _batter2 = _allBatters[1];
        }
      }

      // Restore bowlers
      if (meta['allBowlers'] != null) {
        _allBowlers.clear();
        _allBowlers.addAll((meta['allBowlers'] as List)
            .map((b) => BowlerState.fromJson(b as Map<String, dynamic>)));
        if (_allBowlers.isNotEmpty) {
          _currentBowler = _allBowlers.last;
        }
      }

      // Restore FOW
      if (meta['fowLog'] != null) {
        _fowLog.clear();
        _fowLog.addAll((meta['fowLog'] as List).cast<String>());
      }
    }

    _isInitialized = true;
  }

  Future<void> _syncToSupabase({bool isFinal = false}) async {
    final metadata = {
      'innings': _innings,
      'totalRuns': _totalRuns,
      'wickets': _wickets,
      'legalBalls': _legalBalls,
      'target': _target,
      'extrasWide': _extrasWide,
      'extrasNB': _extrasNB,
      'extrasLB': _extrasLB,
      'extrasB': _extrasB,
      'currentOverBalls': _currentOverBalls.map((b) => b.toJson()).toList(),
      'completedOvers': _completedOvers.map((over) => over.map((b) => b.toJson()).toList()).toList(),
      'allBatters': _allBatters.map((b) => b.toJson()).toList(),
      'allBowlers': _allBowlers.map((b) => b.toJson()).toList(),
      'fowLog': _fowLog,
    };
    try {
      if (isFinal) {
        await ref.read(matchScoreRepositoryProvider).finalizeMatch(
          matchId: widget.matchId,
          homeScore: _innings == 1 ? _totalRuns : (_target - 1),
          awayScore: _innings == 2 ? _totalRuns : 0,
          metadata: metadata,
        );
      } else {
        await ref.read(matchScoreRepositoryProvider).updateScore(
          matchId: widget.matchId,
          homeScore: _innings == 1 ? _totalRuns : (_target - 1),
          awayScore: _innings == 2 ? _totalRuns : 0,
          metadata: metadata,
        );
      }
    } catch (e) {
      debugPrint('Error syncing score: $e');
    }
  }

  // --- Dynamic squad player picker ---

  String? get _battingTeamId {
    final match = ref.read(matchStreamProvider(widget.matchId)).value;
    if (match == null) return null;
    return _innings == 1 ? match.homeTeamId : match.awayTeamId;
  }

  String? get _bowlingTeamId {
    final match = ref.read(matchStreamProvider(widget.matchId)).value;
    if (match == null) return null;
    return _innings == 1 ? match.awayTeamId : match.homeTeamId;
  }

  String get _battingTeamName => _innings == 1 ? widget.homeTeam : widget.awayTeam;
  String get _bowlingTeamName => _innings == 1 ? widget.awayTeam : widget.homeTeam;

  Future<String?> _pickSquadPlayer(String teamName, String? teamId) async {
    if (teamId == null) {
      return await _showGuestOnlyInput(teamName);
    }
    if (!mounted) return null;
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SquadPickerSheet(
        teamName: teamName,
        teamId: teamId,
      ),
    );
  }

  Future<String?> _showGuestOnlyInput(String teamName) {
    final ctrl = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E2E22), Color(0xFF162018), Color(0xFF111A14)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.stroke),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter Player — $teamName', style: AppTextStyles.headingMedium),
              const SizedBox(height: 16),
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.strokeBright),
                ),
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Player name',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: Container(
                  width: double.infinity, height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text('Confirm',
                      style: AppTextStyles.labelLarge.copyWith(color: Colors.black)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Scoring Events ---

  void _addBall(BallEvent event) {
    setState(() {
      _currentOverBalls.add(event);

      // Score runs
      if (event.type == BallType.four) {
        _totalRuns += 4;
        _batter1.runs += 4;
        _batter1.balls++;
        _batter1.fours++;
      } else if (event.type == BallType.six) {
        _totalRuns += 6;
        _batter1.runs += 6;
        _batter1.balls++;
        _batter1.sixes++;
      } else if (event.type == BallType.dot) {
        _batter1.balls++;
      } else if (event.type == BallType.runs) {
        _totalRuns += event.runs;
        _batter1.runs += event.runs;
        _batter1.balls++;
        if (event.runs % 2 == 1) _swapStrike();
      } else if (event.type == BallType.wide) {
        _totalRuns += event.runs;
        _extrasWide += event.runs;
        _syncToSupabase();
        return; // wide doesn't count as a legal ball
      } else if (event.type == BallType.noBall) {
        _totalRuns += event.runs;
        _extrasNB += event.runs;
        _batter1.runs += (event.runs - 1); // batter gets runs scored off the bat
        if ((event.runs - 1) % 2 == 1) _swapStrike();
        _syncToSupabase();
        return; // no ball is not legal
      } else if (event.type == BallType.legBye) {
        _totalRuns += event.runs;
        _extrasLB += event.runs;
        _batter1.balls++;
        if (event.runs % 2 == 1) _swapStrike();
      } else if (event.type == BallType.bye) {
        _totalRuns += event.runs;
        _extrasB += event.runs;
        _batter1.balls++;
        if (event.runs % 2 == 1) _swapStrike();
      } else if (event.type == BallType.wicket) {
        _batter1.balls++;
        _batter1.isOut = true;
        _wickets++;
        _fowLog.add('$_totalRuns/$_wickets (${_batter1.name}, $_oversDisplay ov)');
        if (_wickets < 10) {
          _showNewBatterSheet();
        }
      }

      _legalBalls++;
      _currentBowler.balls++;
      _currentBowler.runsConceded +=
          (event.type == BallType.four ? 4 : event.type == BallType.six ? 6 : event.runs);

      // Auto end over at 6 legal balls
      if (_ballsInCurrentOver == 0 && _legalBalls > 0) {
        _endOver();
      }
    });
    _syncToSupabase();
  }

  void _swapStrike() {
    final tmp = _batter1;
    _batter1 = _batter2;
    _batter2 = tmp;
    
    // Maintain on-strike flags
    _batter1.onStrike = true;
    _batter2.onStrike = false;
  }

  void _endOver() {
    _completedOvers.add(List.from(_currentOverBalls));
    _currentOverBalls.clear();
    _currentBowler.completedOvers++;
    _currentBowler.balls = 0;
    _swapStrike();
    _showNewBowlerSheet();
  }

  void _showNewBowlerSheet() async {
    final name = await _pickSquadPlayer('New Bowler', _bowlingTeamId);
    setState(() {
      final bowlerName = (name == null || name.isEmpty) ? 'Bowler ${_allBowlers.length + 1}' : name;
      _currentBowler = BowlerState(name: bowlerName);
      _allBowlers.add(_currentBowler);
    });
    _syncToSupabase();
  }

  void _showNewBatterSheet() async {
    final name = await _pickSquadPlayer('New Batter', _battingTeamId);
    setState(() {
      final batterName = (name == null || name.isEmpty) ? 'Batter $_nextBatterNumber' : name;
      final nb = BatterState(name: batterName, onStrike: true);
      _nextBatterNumber++;
      _batter1 = nb;
      _allBatters.add(nb);
    });
    _syncToSupabase();
  }

  // --- Advanced Wicket Fielder Log ---

  void _showWicketSheet() {
    const types = ['Bowled', 'Caught', 'LBW', 'Run Out', 'Stumped', 'Hit Wicket', 'Other'];
    String selected = types[0];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => _BottomSheetContainer(
          title: 'Wicket — ${_batter1.name}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: types.map((t) => GestureDetector(
                  onTap: () => setS(() => selected = t),
                  child: AnimatedContainer(
                    duration: 180.ms,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected == t ? AppColors.danger.withAlpha(30) : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected == t ? AppColors.danger : AppColors.stroke,
                      ),
                    ),
                    child: Text(t,
                        style: AppTextStyles.labelMedium.copyWith(
                            color: selected == t ? AppColors.danger : AppColors.textSecondary)),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),
              _SheetBtn(
                label: 'Confirm Wicket',
                color: AppColors.danger,
                onTap: () async {
                  Navigator.pop(ctx);
                  String details = selected;

                  // If Caught, Stumped or Run Out, pick fielder!
                  if (selected == 'Caught' || selected == 'Stumped' || selected == 'Run Out') {
                    final fielder = await _pickSquadPlayer('Fielder', _bowlingTeamId);
                    if (fielder != null && fielder.isNotEmpty) {
                      if (selected == 'Caught') details = 'c $fielder b ${_currentBowler.name}';
                      else if (selected == 'Stumped') details = 'st $fielder b ${_currentBowler.name}';
                      else details = 'run out ($fielder)';
                    }
                  } else if (selected == 'Bowled' || selected == 'LBW') {
                    details = '$selected b ${_currentBowler.name}';
                  }

                  _batter1.dismissal = details;
                  _currentBowler.wickets++;
                  _addBall(const BallEvent(BallType.wicket));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Custom Extras Prompt ---

  void _showWideRunsPrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionPickerSheet(
        title: 'Runs for Wide',
        options: const ['1 Wide (Standard)', '2 Runs (Wide + 1 Run)', '3 Runs', '5 Runs (Wide + 4 Boundary)'],
      ),
    ).then((val) {
      if (val != null) {
        int runs = 1;
        if (val.contains('2')) runs = 2;
        else if (val.contains('3')) runs = 3;
        else if (val.contains('5')) runs = 5;
        _addBall(BallEvent(BallType.wide, runs: runs));
      }
    });
  }

  void _showNoBallRunsPrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionPickerSheet(
        title: 'Runs scored off No Ball',
        options: const ['1 Run (Standard NB)', '2 Runs (NB + 1 Batter Run)', '3 Runs', '5 Runs (NB + 4 Batter Boundary)', '7 Runs (NB + 6 Batter Six)'],
      ),
    ).then((val) {
      if (val != null) {
        int runs = 1;
        if (val.contains('2')) runs = 2;
        else if (val.contains('3')) runs = 3;
        else if (val.contains('5')) runs = 5;
        else if (val.contains('7')) runs = 7;
        _addBall(BallEvent(BallType.noBall, runs: runs));
      }
    });
  }

  // --- Dynamic rename feature ---

  void _changePlayerName(bool isBatter, int idx) async {
    final teamId = isBatter ? _battingTeamId : _bowlingTeamId;
    final teamName = isBatter ? _battingTeamName : _bowlingTeamName;
    final name = await _pickSquadPlayer(teamName, teamId);
    if (name != null && name.isNotEmpty) {
      setState(() {
        if (isBatter) {
          if (idx == 1) _batter1.name = name;
          else _batter2.name = name;
        } else {
          _currentBowler.name = name;
        }
      });
      _syncToSupabase();
    }
  }

  // --- Rendering UI ---

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
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLiveView(),
                      _buildScorecard(),
                    ],
                  ),
                ),
                _buildBallKeyboard(),
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.homeTeam} vs ${widget.awayTeam}',
                        style: AppTextStyles.headingSmall),
                    Row(
                      children: [
                        Container(
                          width: 7, height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text('INNINGS $_innings · LIVE',
                            style: AppTextStyles.overline
                                .copyWith(color: AppColors.danger)),
                      ],
                    ),
                  ],
                ),
              ),
              _HeaderTag(label: '🏏 Cricket'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_totalRuns/$_wickets',
                style: AppTextStyles.scoreLarge,
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '($_oversDisplay ov)',
                  style: AppTextStyles.headingSmall
                      .copyWith(color: AppColors.textTertiary),
                ),
              ),
              const Spacer(),
              if (_innings == 2) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Target: $_target',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.primary)),
                    Text('Need ${_target - _totalRuns} more',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ] else ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('CRR  $_runRate',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.primary)),
                    Text('Run Rate', style: AppTextStyles.bodySmall),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.stroke),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.glassBorder),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          dividerColor: Colors.transparent,
          tabs: ['Live', 'Scorecard']
              .map((t) => Tab(child: Text(t, style: AppTextStyles.labelSmall)))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildLiveView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      children: [
        // Batters
        _SectionLabel(label: 'BATTERS (TAP NAME TO ASSIGN SQUAD PLAYER)'),
        const SizedBox(height: 6),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _BatterHeader(),
              const Divider(height: 1, color: AppColors.divider),
              _BatterRow(batter: _batter1, onStrike: true, onRename: () => _changePlayerName(true, 1)),
              const Divider(height: 1, color: AppColors.divider),
              _BatterRow(batter: _batter2, onStrike: false, onRename: () => _changePlayerName(true, 2)),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // This over
        _SectionLabel(label: 'THIS OVER'),
        const SizedBox(height: 8),
        _ThisOverRow(balls: _currentOverBalls),
        const SizedBox(height: 14),

        // Bowler
        _SectionLabel(label: 'BOWLING (TAP NAME TO ASSIGN SQUAD PLAYER)'),
        const SizedBox(height: 6),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _BowlerHeader(),
              const Divider(height: 1, color: AppColors.divider),
              _BowlerRow(bowler: _currentBowler, onRename: () => _changePlayerName(false, 1)),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Fall of wickets
        if (_fowLog.isNotEmpty) ...[
          _SectionLabel(label: 'FALL OF WICKETS'),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _fowLog
                  .map((f) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.danger.withAlpha(60)),
                        ),
                        child: Text(f,
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.danger)),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // End innings / End match
        Row(
          children: [
            Expanded(
              child: _ActionChip(
                label: 'Swap Strike',
                icon: Icons.swap_horiz_rounded,
                onTap: () => setState(_swapStrike),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionChip(
                label: 'End Innings',
                icon: Icons.stop_circle_outlined,
                color: AppColors.warning,
                onTap: _showEndInningsSheet,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScorecard() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      children: [
        _SectionLabel(label: 'BATTING'),
        const SizedBox(height: 6),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _BatterHeader(),
              const Divider(height: 1, color: AppColors.divider),
              ..._allBatters.expand((b) => [
                    _BatterRow(batter: b, onStrike: b == _batter1 && !b.isOut, onRename: () {}),
                    if (b != _allBatters.last)
                      const Divider(height: 1, color: AppColors.divider),
                  ]),
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Extras',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: AppColors.textSecondary)),
                    ),
                    Text('$_totalExtras  (wd $_extrasWide, nb $_extrasNB, lb $_extrasLB, b $_extrasB)',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Total',
                          style: AppTextStyles.labelLarge
                              .copyWith(color: AppColors.textPrimary)),
                    ),
                    Text('$_totalRuns/$_wickets ($_oversDisplay Ov)',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionLabel(label: 'BOWLING'),
        const SizedBox(height: 6),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _BowlerHeader(),
              const Divider(height: 1, color: AppColors.divider),
              ..._allBowlers.expand((b) => [
                    _BowlerRow(bowler: b, onRename: () {}),
                    if (b != _allBowlers.last)
                      const Divider(height: 1, color: AppColors.divider),
                  ]),
            ],
          ),
        ),
        if (_fowLog.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionLabel(label: 'FALL OF WICKETS'),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: _fowLog
                  .asMap()
                  .entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text('${e.key + 1}.',
                                style: AppTextStyles.bodySmall),
                            const SizedBox(width: 8),
                            Text(e.value,
                                style: AppTextStyles.labelSmall
                                    .copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBallKeyboard() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: const Border(top: BorderSide(color: AppColors.stroke)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _BallKey(label: '·', color: AppColors.textTertiary,
                  onTap: () => _addBall(const BallEvent(BallType.dot))),
              _BallKey(label: '1',
                  onTap: () => _addBall(const BallEvent(BallType.runs, runs: 1))),
              _BallKey(label: '2',
                  onTap: () => _addBall(const BallEvent(BallType.runs, runs: 2))),
              _BallKey(label: '3',
                  onTap: () => _addBall(const BallEvent(BallType.runs, runs: 3))),
              _BallKey(label: '4', color: const Color(0xFF00B0FF),
                  onTap: () => _addBall(const BallEvent(BallType.four))),
              _BallKey(label: '6', color: AppColors.gold,
                  onTap: () => _addBall(const BallEvent(BallType.six))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _BallKey(label: 'W', color: AppColors.danger,
                  flex: 2, onTap: _showWicketSheet),
              _BallKey(label: 'Wd', color: AppColors.warning,
                  onTap: _showWideRunsPrompt),
              _BallKey(label: 'Nb', color: AppColors.warning,
                  onTap: _showNoBallRunsPrompt),
              _BallKey(label: 'Lb',
                  onTap: () => _addBall(const BallEvent(BallType.legBye, runs: 1))),
              _BallKey(label: 'Bye',
                  onTap: () => _addBall(const BallEvent(BallType.bye, runs: 1))),
              _BallKey(
                label: 'End\nOver',
                color: AppColors.primary,
                onTap: () => setState(_endOver),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEndInningsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheetContainer(
        title: 'End Innings',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Innings $_innings ends at $_totalRuns/$_wickets ($_oversDisplay ov)',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _SheetBtn(
              label: _innings == 1 ? 'Start 2nd Innings' : 'End Match',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  if (_innings == 1) {
                    _target = _totalRuns + 1;
                    _innings = 2;
                    _totalRuns = 0;
                    _wickets = 0;
                    _legalBalls = 0;
                    _extrasWide = _extrasNB = _extrasLB = _extrasB = 0;
                    _currentOverBalls.clear();
                    _completedOvers.clear();
                    _fowLog.clear();
                    
                    _batter1 = BatterState(name: 'Opening Batter 1', onStrike: true);
                    _batter2 = BatterState(name: 'Opening Batter 2');
                    _allBatters.clear();
                    _allBatters.addAll([_batter1, _batter2]);
                    _nextBatterNumber = 3;
                    
                    _currentBowler = BowlerState(name: 'Opening Bowler');
                    _allBowlers.clear();
                    _allBowlers.add(_currentBowler);
                  } else {
                    _syncToSupabase(isFinal: true);
                    Navigator.pop(context);
                  }
                });
                if (_innings == 2) {
                  _syncToSupabase();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label, style: AppTextStyles.overline);
}

class _BatterHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(child: Text('Batter', style: AppTextStyles.overline)),
          for (final h in ['R', 'B', '4s', '6s', 'SR'])
            SizedBox(
              width: 36,
              child: Text(h,
                  style: AppTextStyles.overline, textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}

class _BatterRow extends StatelessWidget {
  final BatterState batter;
  final bool onStrike;
  final VoidCallback onRename;

  const _BatterRow({
    required this.batter,
    required this.onStrike,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: onStrike ? AppColors.primarySurface : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          if (onStrike)
            const Text('*',
                style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold))
          else
            const SizedBox(width: 8),
          const SizedBox(width: 2),
          Expanded(
            child: GestureDetector(
              onTap: onRename,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      batter.name,
                      style: AppTextStyles.labelMedium.copyWith(
                          color: batter.isOut ? AppColors.textTertiary : AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!batter.isOut) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.edit_rounded, size: 12, color: AppColors.textTertiary),
                  ],
                ],
              ),
            ),
          ),
          _StatCell('${batter.runs}', bold: true),
          _StatCell('${batter.balls}'),
          _StatCell('${batter.fours}'),
          _StatCell('${batter.sixes}'),
          _StatCell(batter.strikeRate.toStringAsFixed(1)),
        ],
      ),
    );
  }
}

class _BowlerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text('Bowler', style: AppTextStyles.overline)),
          for (final h in ['O', 'M', 'R', 'W', 'Eco'])
            SizedBox(
              width: 36,
              child: Text(h,
                  style: AppTextStyles.overline, textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}

class _BowlerRow extends StatelessWidget {
  final BowlerState bowler;
  final VoidCallback onRename;

  const _BowlerRow({required this.bowler, required this.onRename});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onRename,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      bowler.name,
                      style: AppTextStyles.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit_rounded, size: 12, color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
          _StatCell(bowler.oversDisplay),
          _StatCell('${bowler.maidens}'),
          _StatCell('${bowler.runsConceded}'),
          _StatCell('${bowler.wickets}', bold: bowler.wickets > 0),
          _StatCell(bowler.economy.toStringAsFixed(2)),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final bool bold;
  const _StatCell(this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Text(value,
          textAlign: TextAlign.center,
          style: bold
              ? AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary)
              : AppTextStyles.bodySmall),
    );
  }
}

class _ThisOverRow extends StatelessWidget {
  final List<BallEvent> balls;
  const _ThisOverRow({required this.balls});

  @override
  Widget build(BuildContext context) {
    final dots = List.generate(6, (i) => i < balls.length ? balls[i] : null);
    return Row(
      children: dots.map((b) {
        if (b == null) {
          return Expanded(
            child: Container(
              height: 42,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.stroke, style: BorderStyle.solid),
              ),
            ),
          );
        }
        return Expanded(
          child: Container(
            height: 42,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: b.color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: b.color.withAlpha(80)),
            ),
            alignment: Alignment.center,
            child: Text(b.display,
                style: AppTextStyles.labelMedium.copyWith(color: b.color)),
          ).animate().scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1, 1),
                duration: 200.ms,
                curve: Curves.elasticOut,
              ),
        );
      }).toList(),
    );
  }
}

class _BallKey extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int flex;

  const _BallKey({
    required this.label,
    required this.onTap,
    this.color = AppColors.textSecondary,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(60)),
          ),
          alignment: Alignment.center,
          child: Text(label,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelMedium.copyWith(color: color)),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: AppTextStyles.labelMedium.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _HeaderTag extends StatelessWidget {
  final String label;
  const _HeaderTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
    );
  }
}

class _BottomSheetContainer extends StatelessWidget {
  final String title;
  final Widget child;
  const _BottomSheetContainer({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2E22), Color(0xFF162018), Color(0xFF111A14)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: AppTextStyles.headingMedium),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _OptionPickerSheet extends StatelessWidget {
  final String title;
  final List<String> options;

  const _OptionPickerSheet({required this.title, required this.options});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2E22), Color(0xFF162018), Color(0xFF111A14)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppTextStyles.headingMedium),
          const SizedBox(height: 16),
          Column(
            children: options.map((opt) =>
              GestureDetector(
                onTap: () => Navigator.pop(context, opt),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  alignment: Alignment.center,
                  child: Text(opt, style: AppTextStyles.labelMedium),
                ),
              ),
            ).toList(),
          ),
        ],
      ),
    );
  }
}

class _SquadPickerSheet extends ConsumerStatefulWidget {
  final String teamName;
  final String teamId;

  const _SquadPickerSheet({required this.teamName, required this.teamId});

  @override
  ConsumerState<_SquadPickerSheet> createState() => _SquadPickerSheetState();
}

class _SquadPickerSheetState extends ConsumerState<_SquadPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _guestCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _guestCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(teamPlayersProvider(widget.teamId));
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2E22), Color(0xFF162018), Color(0xFF111A14)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Pick Player — ${widget.teamName}', style: AppTextStyles.headingMedium),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search Box
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.stroke),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search squad...',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textTertiary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(top: 8),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: 12),
          // Players List
          SizedBox(
            height: 200,
            child: playersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
              error: (err, st) => Center(child: Text('Could not load squad', style: AppTextStyles.bodySmall)),
              data: (List<Player> players) {
                final filtered = players.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Text('No squad players found', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final p = filtered[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => Navigator.pop(context, p.name),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primarySurface,
                        child: Text(
                          p.name.substring(0, p.name.length >= 2 ? 2 : 1).toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, fontSize: 10),
                        ),
                      ),
                      title: Text(p.name, style: AppTextStyles.labelMedium),
                      subtitle: Text(p.role ?? 'Squad Player', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
                      trailing: p.jerseyNumber != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(6)),
                              child: Text('#${p.jerseyNumber}', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.stroke),
          const SizedBox(height: 8),
          Text('Guest/Unlisted Player (Fallback)', style: AppTextStyles.overline),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: TextField(
                    controller: _guestCtrl,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Guest Player',
                      hintStyle: TextStyle(color: AppColors.textTertiary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  final guest = _guestCtrl.text.trim();
                  if (guest.isNotEmpty) {
                    Navigator.pop(context, guest);
                  }
                },
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text('Add', style: AppTextStyles.labelMedium.copyWith(color: Colors.black)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SheetBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: AppTextStyles.labelLarge.copyWith(color: Colors.black)),
      ),
    );
  }
}
