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

enum FootballEventType { goal, ownGoal, yellowCard, redCard, sub, halfTime, fullTime }

class FootballEvent {
  final FootballEventType type;
  final String team;
  final String player;
  final int minute;
  final String? assist;
  final String? detail; // e.g. Goal type or Card reason

  const FootballEvent({
    required this.type,
    required this.team,
    required this.player,
    required this.minute,
    this.assist,
    this.detail,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'team': team,
        'player': player,
        'minute': minute,
        'assist': assist,
        'detail': detail,
      };

  factory FootballEvent.fromJson(Map<String, dynamic> json) => FootballEvent(
        type: FootballEventType.values.firstWhere(
          (val) => val.name == json['type'],
          orElse: () => FootballEventType.goal,
        ),
        team: json['team'] as String,
        player: json['player'] as String,
        minute: json['minute'] as int,
        assist: json['assist'] as String?,
        detail: json['detail'] as String?,
      );

  IconData get icon {
    switch (type) {
      case FootballEventType.goal:     return Icons.sports_soccer_rounded;
      case FootballEventType.ownGoal:  return Icons.sports_soccer_rounded;
      case FootballEventType.yellowCard: return Icons.square_rounded;
      case FootballEventType.redCard:  return Icons.square_rounded;
      case FootballEventType.sub:      return Icons.swap_horiz_rounded;
      case FootballEventType.halfTime: return Icons.pause_circle_rounded;
      case FootballEventType.fullTime: return Icons.stop_circle_rounded;
    }
  }

  Color get color {
    switch (type) {
      case FootballEventType.goal:     return AppColors.primary;
      case FootballEventType.ownGoal:  return AppColors.danger;
      case FootballEventType.yellowCard: return AppColors.gold;
      case FootballEventType.redCard:  return AppColors.danger;
      case FootballEventType.sub:      return AppColors.info;
      case FootballEventType.halfTime: return AppColors.textTertiary;
      case FootballEventType.fullTime: return AppColors.textTertiary;
    }
  }

  String get label {
    switch (type) {
      case FootballEventType.goal:     return 'Goal';
      case FootballEventType.ownGoal:  return 'Own Goal';
      case FootballEventType.yellowCard: return 'Yellow Card';
      case FootballEventType.redCard:  return 'Red Card';
      case FootballEventType.sub:      return 'Substitution';
      case FootballEventType.halfTime: return 'Half Time';
      case FootballEventType.fullTime: return 'Full Time';
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class FootballScoringScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String homeTeam;
  final String awayTeam;

  const FootballScoringScreen({
    super.key,
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
  });

  @override
  ConsumerState<FootballScoringScreen> createState() => _FootballScoringScreenState();
}

class _FootballScoringScreenState extends ConsumerState<FootballScoringScreen> {
  bool _isInitialized = false;
  int _homeScore = 0;
  int _awayScore = 0;
  int _minute = 0;
  int _lastSyncedMinute = 0;
  bool _isRunning = false;
  DateTime? _clockStartedAt;
  Timer? _localTimer;
  int _half = 1;
  final List<FootballEvent> _events = [];

  // Advanced Stats Tracker
  Map<String, dynamic> _homeStats = {
    'shots': 0, 'shots_on_target': 0, 'corners': 0, 'fouls': 0, 'offsides': 0, 'saves': 0
  };
  Map<String, dynamic> _awayStats = {
    'shots': 0, 'shots_on_target': 0, 'corners': 0, 'fouls': 0, 'offsides': 0, 'saves': 0
  };

  bool _showStatsPanel = false;

  @override
  void dispose() {
    _localTimer?.cancel();
    super.dispose();
  }

  void _addEvent(FootballEvent event) {
    setState(() => _events.insert(0, event));
    _syncToSupabase();
  }

  Future<void> _syncToSupabase({bool isFinal = false}) async {
    final metadata = {
      'events': _events.map((e) => e.toJson()).toList(),
      'stats': {
        'home': _homeStats,
        'away': _awayStats,
      },
      'minute': _minute,
      'half': _half,
      'isRunning': _isRunning,
      'clockStartedAt': _clockStartedAt?.toIso8601String(),
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

  void _initializeFromMatch(Match match) {
    if (_isInitialized) return;
    _homeScore = match.homeScore ?? 0;
    _awayScore = match.awayScore ?? 0;

    final meta = match.metadata;
    _lastSyncedMinute = (meta['minute'] as int?) ?? 0;
    _half = (meta['half'] as int?) ?? 1;
    _isRunning = (meta['isRunning'] as bool?) ?? false;

    if (_isRunning) {
      final startedStr = meta['clockStartedAt'] as String?;
      if (startedStr != null) {
        _clockStartedAt = DateTime.tryParse(startedStr);
        if (_clockStartedAt != null) {
          final elapsed = DateTime.now().difference(_clockStartedAt!).inSeconds ~/ 60;
          _minute = _lastSyncedMinute + elapsed;
        } else {
          _minute = _lastSyncedMinute;
        }
      } else {
        _minute = _lastSyncedMinute;
      }
    } else {
      _minute = _lastSyncedMinute;
    }

    // Load Events
    if (meta['events'] != null) {
      final evList = meta['events'] as List;
      _events.clear();
      _events.addAll(evList.map((e) => FootballEvent.fromJson(e as Map<String, dynamic>)));
    }

    // Load Stats
    if (meta['stats'] != null) {
      final statsMap = meta['stats'] as Map;
      if (statsMap['home'] != null) {
        _homeStats = Map<String, dynamic>.from(statsMap['home'] as Map);
      }
      if (statsMap['away'] != null) {
        _awayStats = Map<String, dynamic>.from(statsMap['away'] as Map);
      }
    }

    _isInitialized = true;
    if (_isRunning) {
      _runClock();
    }
  }

  // --- Dynamic Picker Logic ---

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

  // --- Advanced Scenarios ---

  void _logGoal(Match match, String team) async {
    final teamId = team == widget.homeTeam ? match.homeTeamId : match.awayTeamId;
    final scorer = await _pickSquadPlayer(team, teamId);
    if (scorer == null || scorer.isEmpty) return;

    if (!mounted) return;
    // Pick Goal Type
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionPickerSheet(
        title: 'Goal Type',
        options: const ['Regular', 'Header', 'Penalty', 'Free Kick', 'Own Goal'],
      ),
    );
    if (type == null) return;

    String? assist;
    if (type != 'Own Goal') {
      if (!mounted) return;
      // Pick Assist (Optional)
      final wantAssist = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _YesNoPickerSheet(title: 'Was there an assist?'),
      );
      if (wantAssist == true) {
        assist = await _pickSquadPlayer(team, teamId);
        if (assist == scorer) assist = null; // Can't assist yourself
      }
    }

    setState(() {
      if (type == 'Own Goal') {
        if (team == widget.homeTeam) {
          _awayScore++;
        } else {
          _homeScore++;
        }
      } else {
        if (team == widget.homeTeam) {
          _homeScore++;
        } else {
          _awayScore++;
        }
      }
    });

    _addEvent(FootballEvent(
      type: type == 'Own Goal' ? FootballEventType.ownGoal : FootballEventType.goal,
      team: team,
      player: scorer,
      minute: _minute,
      assist: assist,
      detail: type,
    ));
  }

  void _logCard(Match match, FootballEventType cardType) async {
    final team = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionPickerSheet(
        title: 'Select Team',
        options: [widget.homeTeam, widget.awayTeam],
      ),
    );
    if (team == null) return;

    final teamId = team == widget.homeTeam ? match.homeTeamId : match.awayTeamId;
    final player = await _pickSquadPlayer(team, teamId);
    if (player == null || player.isEmpty) return;

    if (!mounted) return;
    // Pick Card Reason
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionPickerSheet(
        title: 'Card Reason',
        options: const ['Foul', 'Dissent', 'Handball', 'Tactical', 'Time Wasting'],
      ),
    );
    if (reason == null) return;

    // Check if second yellow card
    bool isSecondYellow = false;
    if (cardType == FootballEventType.yellowCard) {
      final yellowCount = _events.where((e) => 
        e.type == FootballEventType.yellowCard && 
        e.player == player && 
        e.team == team
      ).length;
      if (yellowCount >= 1) {
        isSecondYellow = true;
      }
    }

    _addEvent(FootballEvent(
      type: isSecondYellow ? FootballEventType.redCard : cardType,
      team: team,
      player: player,
      minute: _minute,
      detail: isSecondYellow ? 'Second Yellow' : reason,
    ));
  }

  void _logSubstitution(Match match) async {
    final team = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionPickerSheet(
        title: 'Select Team',
        options: [widget.homeTeam, widget.awayTeam],
      ),
    );
    if (team == null) return;

    final teamId = team == widget.homeTeam ? match.homeTeamId : match.awayTeamId;
    
    // Pick Player Out
    final playerOut = await _pickSquadPlayer('$team (Out)', teamId);
    if (playerOut == null || playerOut.isEmpty) return;

    // Pick Player In
    final playerIn = await _pickSquadPlayer('$team (In)', teamId);
    if (playerIn == null || playerIn.isEmpty) return;

    _addEvent(FootballEvent(
      type: FootballEventType.sub,
      team: team,
      player: playerOut,
      minute: _minute,
      assist: playerIn,
    ));
  }

  // --- Clock Logic ---

  void _runClock() {
    _localTimer?.cancel();
    _localTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRunning && _clockStartedAt != null) {
        final elapsedSec = DateTime.now().difference(_clockStartedAt!).inSeconds;
        final newMin = _lastSyncedMinute + (elapsedSec ~/ 60);
        if (newMin != _minute) {
          setState(() {
            _minute = newMin;
          });
          if (elapsedSec % 15 == 0) {
            _syncToSupabase();
          }
        }
      }
    });
  }

  void _halfTime() {
    setState(() {
      if (_isRunning) {
        if (_clockStartedAt != null) {
          _minute = _lastSyncedMinute + DateTime.now().difference(_clockStartedAt!).inSeconds ~/ 60;
        }
        _isRunning = false;
        _clockStartedAt = null;
        _lastSyncedMinute = _minute;
        _localTimer?.cancel();
      }

      if (_half == 1) {
        _half = 2;
        _minute = 45;
        _lastSyncedMinute = 45;
        _events.insert(0, FootballEvent(
          type: FootballEventType.halfTime,
          team: '',
          player: 'Half Time',
          minute: 45,
        ));
      } else {
        _events.insert(0, FootballEvent(
          type: FootballEventType.fullTime,
          team: '',
          player: 'Full Time',
          minute: _minute,
        ));
      }
    });
    _syncToSupabase(isFinal: _half == 2);
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
                _buildHeader(topPad, match),
                if (_showStatsPanel)
                  Expanded(child: _buildStatsPanel())
                else
                  Expanded(child: _buildEventFeed()),
                _buildActionBar(match),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(double topPad, Match match) {
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
                  color: _isRunning ? AppColors.liveGlow : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isRunning ? AppColors.danger : AppColors.stroke,
                  ),
                ),
                child: Row(
                  children: [
                    if (_isRunning)
                      Container(
                        width: 7, height: 7,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.danger, shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      _isRunning ? "$_minute'" : (_half == 2 ? 'Full Time' : 'HT $_half'),
                      style: AppTextStyles.labelMedium.copyWith(
                        color: _isRunning ? AppColors.danger : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _SportTag(label: '⚽ Football'),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Text(_half == 1 ? '1ST HALF' : '2ND HALF',
                    style: AppTextStyles.overline),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isRunning = !_isRunning;
                      if (_isRunning) {
                        _clockStartedAt = DateTime.now();
                        _lastSyncedMinute = _minute;
                        _runClock();
                      } else {
                        if (_clockStartedAt != null) {
                          _minute = _lastSyncedMinute + DateTime.now().difference(_clockStartedAt!).inSeconds ~/ 60;
                        }
                        _clockStartedAt = null;
                        _lastSyncedMinute = _minute;
                        _localTimer?.cancel();
                      }
                    });
                    _syncToSupabase();
                  },
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isRunning ? AppColors.liveGlow : AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isRunning ? AppColors.danger.withAlpha(80) : AppColors.glassBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 16,
                          color: _isRunning ? AppColors.danger : AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isRunning ? 'Pause Clock' : 'Start Clock',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: _isRunning ? AppColors.danger : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _halfTime,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.skip_next_rounded,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(_half == 1 ? 'Half Time' : 'Full Time',
                          style: AppTextStyles.labelSmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventFeed() {
    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_soccer_rounded,
                color: AppColors.textTertiary, size: 48),
            const SizedBox(height: 12),
            Text('No events yet', style: AppTextStyles.headingSmall
                .copyWith(color: AppColors.textTertiary)),
            const SizedBox(height: 6),
            Text('Use the buttons below to log match events',
                style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      itemCount: _events.length,
      itemBuilder: (_, i) {
        final e = _events[i];
        final isHome = e.team == widget.homeTeam;
        final isSystem = e.type == FootballEventType.halfTime ||
            e.type == FootballEventType.fullTime;
        if (isSystem) {
          return Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Text(e.player,
                  style: AppTextStyles.overline),
            ),
          ).animate().fadeIn(duration: 300.ms);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              if (isHome) ...[
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: e.color.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(e.icon, size: 14, color: e.color),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.player, style: AppTextStyles.labelMedium),
                              if (e.type == FootballEventType.sub)
                                Text('In: ${e.assist}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary))
                              else
                                Text('${e.label}${e.detail != null ? " (${e.detail})" : ""}${e.assist != null ? " • Assist: ${e.assist}" : ""}', style: AppTextStyles.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _MinuteBadge(minute: e.minute),
                const SizedBox(width: 8),
                const SizedBox(width: 80),
              ] else ...[
                const SizedBox(width: 80),
                const SizedBox(width: 8),
                _MinuteBadge(minute: e.minute),
                const SizedBox(width: 8),
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(e.player, style: AppTextStyles.labelMedium),
                              if (e.type == FootballEventType.sub)
                                Text('In: ${e.assist}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary))
                              else
                                Text('${e.label}${e.detail != null ? " (${e.detail})" : ""}${e.assist != null ? " • Assist: ${e.assist}" : ""}', style: AppTextStyles.bodySmall),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: e.color.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(e.icon, size: 14, color: e.color),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0, duration: 300.ms);
      },
    );
  }

  Widget _buildStatsPanel() {
    final metrics = [
      ('Shots', 'shots'),
      ('Shots on Target', 'shots_on_target'),
      ('Corners', 'corners'),
      ('Fouls', 'fouls'),
      ('Offsides', 'offsides'),
      ('Saves', 'saves'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: metrics.map((m) {
        final label = m.$1;
        final key = m.$2;
        final hVal = _homeStats[key] ?? 0;
        final aVal = _awayStats[key] ?? 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Text(label, style: AppTextStyles.overline.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Home Controls
                    Row(
                      children: [
                        _StatBtn(icon: Icons.remove_rounded, onTap: () {
                          if (hVal > 0) {
                            setState(() => _homeStats[key] = hVal - 1);
                            _syncToSupabase();
                          }
                        }),
                        const SizedBox(width: 10),
                        Text('$hVal', style: AppTextStyles.headingSmall.copyWith(color: AppColors.primary)),
                        const SizedBox(width: 10),
                        _StatBtn(icon: Icons.add_rounded, onTap: () {
                          setState(() => _homeStats[key] = hVal + 1);
                          _syncToSupabase();
                        }),
                      ],
                    ),
                    // Away Controls
                    Row(
                      children: [
                        _StatBtn(icon: Icons.remove_rounded, onTap: () {
                          if (aVal > 0) {
                            setState(() => _awayStats[key] = aVal - 1);
                            _syncToSupabase();
                          }
                        }),
                        const SizedBox(width: 10),
                        Text('$aVal', style: AppTextStyles.headingSmall.copyWith(color: AppColors.textPrimary)),
                        const SizedBox(width: 10),
                        _StatBtn(icon: Icons.add_rounded, onTap: () {
                          setState(() => _awayStats[key] = aVal + 1);
                          _syncToSupabase();
                        }),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionBar(Match match) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.stroke)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  label: 'Goal',
                  icon: Icons.sports_soccer_rounded,
                  color: AppColors.primary,
                  onTap: () => _logGoal(match, widget.homeTeam),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionBtn(
                  label: 'Cards',
                  icon: Icons.square_rounded,
                  color: AppColors.gold,
                  onTap: () => _logCard(match, FootballEventType.yellowCard),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionBtn(
                  label: 'Subs',
                  icon: Icons.swap_horiz_rounded,
                  color: AppColors.info,
                  onTap: () => _logSubstitution(match),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isInitialized = false;
                    _showStatsPanel = !_showStatsPanel;
                  });
                },
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: _showStatsPanel ? AppColors.primarySurface : AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _showStatsPanel ? AppColors.glassBorder : AppColors.stroke),
                  ),
                  child: Icon(Icons.analytics_rounded, size: 20, color: _showStatsPanel ? AppColors.primary : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Sub-sheets & Helpers ──────────────────────────────────────────────────────

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
                      hintText: 'e.g. Guest Scorer',
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

class _YesNoPickerSheet extends StatelessWidget {
  final String title;

  const _YesNoPickerSheet({required this.title});

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
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, true),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    alignment: Alignment.center,
                    child: Text('Yes', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.stroke),
                    ),
                    alignment: Alignment.center,
                    child: Text('No', style: AppTextStyles.labelMedium),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color.withAlpha(22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.labelMedium.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _StatBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StatBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Icon(icon, size: 16, color: AppColors.textSecondary),
      ),
    );
  }
}

class _MinuteBadge extends StatelessWidget {
  final int minute;
  const _MinuteBadge({required this.minute});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Text("$minute'", style: AppTextStyles.bodySmall),
    );
  }
}

class _SportTag extends StatelessWidget {
  final String label;
  const _SportTag({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
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
}
