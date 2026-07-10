import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/player.dart';
import '../../../core/models/team.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/hyper_grid_background.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/top_bar.dart';
import '../data/tournament_template_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────────────────────

class CreateTournamentScreen extends ConsumerStatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  ConsumerState<CreateTournamentScreen> createState() =>
      _CreateTournamentScreenState();
}

class _CreateTournamentScreenState
    extends ConsumerState<CreateTournamentScreen> {
  int _step = 0;
  bool _isSubmitting = false;

  // Step 1
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _locController = TextEditingController();
  String _selectedSport = '';
  String _tournamentType = 'teams';

  // Step 2
  String _selectedFormat = '';

  // Step 3
  int _winPts = 3;
  int _drawPts = 1;
  int _lossPts = 0;
  final _prizesController = TextEditingController();
  final Map<String, int> _seriesLegs = {
    'final': 1, 'third_place': 1, 'semi': 2,
    'quarter': 1, 'r16': 1, 'r32': 1, 'r64': 1,
  };

  // Step 4
  final Set<String> _selectedTeamIds = {};
  final Set<String> _selectedPlayerIds = {};
  final Map<String, String> _selectedTeamNames = {};
  final Map<String, String> _selectedPlayerNames = {};
  final Map<String, String> _selectedPlayerProfileIds = {};

  // Step 5
  String _drawMethod = '';
  bool _drawCompleted = false;
  List<String> _drawnOrder = [];

  List<String> get _stepTitles => [
        'Basic Info',
        'Format',
        'Rules',
        _tournamentType == 'individual' ? 'Players' : 'Teams',
        'Draw',
        'Confirm'
      ];

  int get _totalSteps => 6;

  static const _sports = [
    ('football', 'Football', Icons.sports_soccer_rounded),
    ('cricket', 'Cricket', Icons.sports_cricket_rounded),
    ('badminton', 'Badminton', Icons.sports_tennis_rounded),
    ('efootball', 'eFootball', Icons.sports_esports_rounded),
  ];

  static const _formats = [
    ('league', 'Round Robin League', Icons.view_list_rounded, 'All teams play each other, full fixture list'),
    ('knockout', 'Knockout / Elimination', Icons.account_tree_rounded, 'Lose once = out'),
    ('league_knockout', 'League + Knockout', Icons.workspaces_rounded, 'Group stage → knockout final'),
    ('groups_knockout', 'Groups + Knockout', Icons.grid_view_rounded, 'Teams split into groups, top teams advance'),
    ('custom', 'Custom Format', Icons.tune_rounded, 'Define your own rules'),
  ];

  static const _drawOptions = [
    ('random', 'Random Draw', Icons.shuffle_rounded, 'RECOMMENDED'),
    ('seeded', 'By Seeding', Icons.leaderboard_rounded, ''),
    ('random_seeded', 'Random + Seeded', Icons.merge_rounded, ''),
    ('manual', 'Manual Assignment', Icons.edit_rounded, ''),
  ];

  static const _seriesRounds = [
    ('final', 'Final'),
    ('third_place', '3rd Place'),
    ('semi', 'Semifinals'),
    ('quarter', 'Quarter Finals'),
    ('r16', 'Round of 16'),
    ('r32', 'Round of 32'),
    ('r64', 'Round of 64'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _locController.dispose();
    _prizesController.dispose();
    super.dispose();
  }

  int get _selectionCount =>
      _tournamentType == 'individual' ? _selectedPlayerIds.length : _selectedTeamIds.length;

  bool get _canProceed => switch (_step) {
        0 => _nameController.text.trim().isNotEmpty && _selectedSport.isNotEmpty,
        1 => _selectedFormat.isNotEmpty,
        2 => true,
        3 => _selectionCount >= 2,
        4 => _drawCompleted || _drawMethod == 'manual',
        _ => true,
      };

  void _next() {
    if (_step == 0 && _nameController.text.trim().isEmpty) {
      _showSnack('Tournament name is required');
      return;
    }
    if (_step == 3 && _selectionCount < 2) {
      _showSnack('Select at least 2 ${_tournamentType == "individual" ? "players" : "teams"}');
      return;
    }
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _handlePublish();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      context.pop();
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.bgCard,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Templates ──────────────────────────────────────────────────────────────

  final _templateService = TournamentTemplateService();

  void _applyTemplate(TournamentTemplate t) {
    setState(() {
      _selectedSport = t.sport;
      _tournamentType = t.type;
      _drawMethod = t.drawMethod;
      _drawCompleted = false;
      _drawnOrder = [];
      _selectedTeamIds.clear();
      _selectedPlayerIds.clear();
      _selectedTeamNames.clear();
      _selectedPlayerNames.clear();
      _selectedPlayerProfileIds.clear();
    });
    _showSnack('Template "${t.name}" applied');
  }

  Future<void> _showLoadTemplateSheet() async {
    final ctx = context;
    final templates = await _templateService.loadAll();
    if (!mounted) return;
    if (templates.isEmpty) {
      _showSnack('No saved templates yet');
      return;
    }
    // ignore: use_build_context_synchronously
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Saved Templates', style: AppTextStyles.headingSmall),
              const SizedBox(height: 16),
              ...templates.asMap().entries.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.value.name, style: AppTextStyles.labelMedium),
                    subtitle: Text(
                      '${e.value.sport.toUpperCase()} · ${e.value.type}',
                      style: AppTextStyles.bodySmall,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger, size: 18),
                      onPressed: () async {
                        await _templateService.delete(e.key);
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      },
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _applyTemplate(e.value);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAsTemplate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedSport.isEmpty) {
      _showSnack('Fill in name and sport first');
      return;
    }
    final template = TournamentTemplate(
      name: name,
      sport: _selectedSport,
      type: _tournamentType,
      drawMethod: _drawMethod,
      maxTeams: _selectionCount,
      isPublic: false,
    );
    await _templateService.save(template);
    if (mounted) _showSnack('Template saved!');
  }

  Future<void> _handlePublish() async {
    setState(() => _isSubmitting = true);
    try {
      final user = ref.read(authRepositoryProvider).currentUser;

      // 1. Create tournament
      final tournament = await ref.read(tournamentRepositoryProvider).create({
        'name': _nameController.text.trim(),
        'sport': _selectedSport,
        'type': _tournamentType,
        'description': _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        'location': _locController.text.trim().isEmpty
            ? null
            : _locController.text.trim(),
        'status': 'upcoming',
        'organizer_id': user?.id,
        'max_teams': 16,
        'current_teams': 0,
      });

      final Map<String, String> nameToTeamId = {};

      // 2. Resolve participants
      if (_tournamentType == 'individual') {
        final allTeams = await ref.read(teamRepositoryProvider).fetchAll(sport: _selectedSport, isIndividual: true);
        
        for (final id in _selectedPlayerIds) {
          final playerName = _selectedPlayerNames[id]!;
          final playerProfileId = _selectedPlayerProfileIds[id]!;
          
          Team? team;
          for (final t in allTeams) {
            if (t.captainId == playerProfileId) {
              team = t;
              break;
            }
          }
          if (team == null) {
            team = await ref.read(teamRepositoryProvider).create({
              'name': playerName,
              'sport': _selectedSport,
              'captain_id': playerProfileId,
              'player_count': 1,
              'is_individual': true,
            });
          }
          nameToTeamId[playerName] = team.id;
        }
      } else {
        for (final entry in _selectedTeamNames.entries) {
          nameToTeamId[entry.value] = entry.key;
        }
      }

      // 3. Enroll participants into the tournament
      final teamIds = nameToTeamId.values.toList();
      await Future.wait(teamIds.map((tid) => ref.read(tournamentRepositoryProvider).joinTournament(tournament.id, tid)));

      // 4. Generate & schedule matches
      final drawList = _drawCompleted && _drawnOrder.isNotEmpty
          ? _drawnOrder
          : (_tournamentType == 'individual'
              ? _selectedPlayerNames.values.toList()
              : _selectedTeamNames.values.toList());

      final List<Map<String, dynamic>> matchesToInsert = [];
      final orderedTeamIds = drawList.map((name) => nameToTeamId[name]).whereType<String>().toList();

      List<Map<String, dynamic>> generateRoundRobin({
        required String tournamentId,
        required List<String> teamIds,
        required Map<String, String> nameToTeamId,
        required String sport,
        required DateTime startDate,
        Map<String, dynamic> extraMetadata = const {},
      }) {
        final List<Map<String, dynamic>> list = [];
        final n = teamIds.length;
        final List<String?> teamsList = List<String?>.from(teamIds);
        if (n % 2 != 0) {
          teamsList.add(null);
        }
        final numTeams = teamsList.length;
        final numRounds = numTeams - 1;
        final matchesPerRound = numTeams ~/ 2;

        for (int round = 0; round < numRounds; round++) {
          for (int matchIdx = 0; matchIdx < matchesPerRound; matchIdx++) {
            final home = teamsList[matchIdx];
            final away = teamsList[numTeams - 1 - matchIdx];

            if (home != null && away != null) {
              final homeName = nameToTeamId.entries.firstWhere((e) => e.value == home).key;
              final awayName = nameToTeamId.entries.firstWhere((e) => e.value == away).key;

              list.add({
                'tournament_id': tournamentId,
                'home_team_id': home,
                'away_team_id': away,
                'home_team_name': homeName,
                'away_team_name': awayName,
                'sport': sport,
                'status': 'scheduled',
                'metadata': extraMetadata,
                'scheduled_at': startDate.add(Duration(days: round, hours: matchIdx)).toIso8601String(),
              });
            }
          }
          final last = teamsList.removeLast();
          teamsList.insert(1, last);
        }
        return list;
      }

      final format = _selectedFormat;
      if (format == 'league' || format == 'league_knockout') {
        matchesToInsert.addAll(generateRoundRobin(
          tournamentId: tournament.id,
          teamIds: orderedTeamIds,
          nameToTeamId: nameToTeamId,
          sport: _selectedSport,
          startDate: DateTime.now(),
          extraMetadata: format == 'league_knockout' ? {'group': 'Group Stage'} : {},
        ));
      } else if (format == 'groups_knockout') {
        final n = orderedTeamIds.length;
        int numGroups = 1;
        if (n > 8) {
          numGroups = 4;
        } else if (n > 4) {
          numGroups = 2;
        }

        final groups = List.generate(numGroups, (_) => <String>[]);
        for (int i = 0; i < n; i++) {
          groups[i % numGroups].add(orderedTeamIds[i]);
        }

        for (int gIdx = 0; gIdx < numGroups; gIdx++) {
          final groupName = 'Group ${String.fromCharCode(65 + gIdx)}';
          final groupTeams = groups[gIdx];
          if (groupTeams.length >= 2) {
            matchesToInsert.addAll(generateRoundRobin(
              tournamentId: tournament.id,
              teamIds: groupTeams,
              nameToTeamId: nameToTeamId,
              sport: _selectedSport,
              startDate: DateTime.now().add(Duration(days: gIdx * 3)),
              extraMetadata: {'group': groupName},
            ));
          }
        }
      } else {
        // Knockout / Custom
        DateTime matchDate = DateTime.now();
        for (int i = 0; i < orderedTeamIds.length; i += 2) {
          if (i + 1 < orderedTeamIds.length) {
            final home = orderedTeamIds[i];
            final away = orderedTeamIds[i + 1];
            final homeName = drawList[i];
            final awayName = drawList[i + 1];

            matchesToInsert.add({
              'tournament_id': tournament.id,
              'home_team_id': home,
              'away_team_id': away,
              'home_team_name': homeName,
              'away_team_name': awayName,
              'sport': _selectedSport,
              'status': 'scheduled',
              'metadata': {'round': 'Round 1'},
              'scheduled_at': matchDate.add(Duration(hours: i)).toIso8601String(),
            });
          }
        }
      }

      if (matchesToInsert.isNotEmpty) {
        await Supabase.instance.client.from('matches').insert(matchesToInsert);
      }

      ref.invalidate(tournamentsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnack('Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: HyperGridBackground(
        child: Column(
          children: [
            TopBar(
              title: 'Create Tournament',
              subtitle: 'Step ${_step + 1} of $_totalSteps · ${_stepTitles[_step]}',
              showBack: true,
              actions: [
                if (_step == 0)
                  GestureDetector(
                    onTap: _showLoadTemplateSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.stroke),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bookmark_outline_rounded,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 5),
                          Text('Templates',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                if (_step == _totalSteps - 1)
                  GestureDetector(
                    onTap: _saveAsTemplate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.stroke),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bookmark_add_outlined,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Text('Save Template',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            _StepIndicator(current: _step, total: _totalSteps),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(key: ValueKey(_step), child: _buildStep()),
              ),
            ),
            _BottomBar(
              step: _step,
              canProceed: _canProceed,
              isLast: _step == _totalSteps - 1,
              isSubmitting: _isSubmitting,
              onBack: _back,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() => switch (_step) {
        0 => _Step1BasicInfo(
            nameController: _nameController,
            descController: _descController,
            locController: _locController,
            selectedSport: _selectedSport,
            tournamentType: _tournamentType,
            sports: _sports,
            onSportSelected: (s) {
              final hadSelections = _selectedTeamIds.isNotEmpty || _selectedPlayerIds.isNotEmpty;
              setState(() {
                _selectedSport = s;
                if (s == 'football' || s == 'cricket') {
                  _tournamentType = 'teams';
                } else if (s == 'efootball' || s == 'badminton') {
                  _tournamentType = 'individual';
                } else {
                  _tournamentType = 'teams';
                }
                _selectedTeamIds.clear();
                _selectedPlayerIds.clear();
                _selectedTeamNames.clear();
                _selectedPlayerNames.clear();
                _selectedPlayerProfileIds.clear();
                _drawCompleted = false;
                _drawMethod = '';
                _drawnOrder = [];
              });
              if (hadSelections) {
                _showSnack('Sport changed — previous selections cleared');
              }
            },
            onTypeSelected: (t) {
              final hadSelections = _selectedTeamIds.isNotEmpty || _selectedPlayerIds.isNotEmpty;
              setState(() {
                _tournamentType = t;
                _selectedTeamIds.clear();
                _selectedPlayerIds.clear();
                _selectedTeamNames.clear();
                _selectedPlayerNames.clear();
                _selectedPlayerProfileIds.clear();
                _drawCompleted = false;
                _drawMethod = '';
                _drawnOrder = [];
              });
              if (hadSelections) {
                _showSnack('Type changed — previous selections cleared');
              }
            },
            onChanged: (_) => setState(() {}),
          ),
        1 => _Step2Format(
            selected: _selectedFormat,
            formats: _formats,
            onSelect: (f) => setState(() => _selectedFormat = f),
          ),
        2 => _Step3Rules(
            winPts: _winPts,
            drawPts: _drawPts,
            lossPts: _lossPts,
            seriesLegs: _seriesLegs,
            prizesController: _prizesController,
            seriesRounds: _seriesRounds,
            onWinChanged: (v) => setState(() => _winPts = v),
            onDrawChanged: (v) => setState(() => _drawPts = v),
            onLossChanged: (v) => setState(() => _lossPts = v),
            onLegsChanged: (key, v) => setState(() => _seriesLegs[key] = v),
          ),
        3 => _Step4Teams(
            tournamentType: _tournamentType,
            sport: _selectedSport,
            selectedTeamIds: _selectedTeamIds,
            selectedPlayerIds: _selectedPlayerIds,
            onToggleTeam: (id, name) => setState(() {
              if (_selectedTeamIds.contains(id)) {
                _selectedTeamIds.remove(id);
                _selectedTeamNames.remove(id);
              } else {
                _selectedTeamIds.add(id);
                _selectedTeamNames[id] = name;
              }
            }),
            onTogglePlayer: (id, name, profileId) => setState(() {
              if (_selectedPlayerIds.contains(id)) {
                _selectedPlayerIds.remove(id);
                _selectedPlayerNames.remove(id);
                _selectedPlayerProfileIds.remove(id);
              } else {
                _selectedPlayerIds.add(id);
                _selectedPlayerNames[id] = name;
                _selectedPlayerProfileIds[id] = profileId;
              }
            }),
          ),
        4 => _Step5Draw(
            drawMethod: _drawMethod,
            drawOptions: _drawOptions,
            selectedNames: _tournamentType == 'individual'
                ? _selectedPlayerNames.values.toList()
                : _selectedTeamNames.values.toList(),
            drawCompleted: _drawCompleted,
            drawnOrder: _drawnOrder,
            onMethodSelect: (m) => setState(() {
              _drawMethod = m;
              _drawCompleted = false;
              _drawnOrder = [];
            }),
            onDrawComplete: (order) => setState(() {
              _drawnOrder = order;
              _drawCompleted = true;
            }),
          ),
        _ => _Step6Confirm(
            name: _nameController.text,
            sport: _selectedSport,
            format: _selectedFormat,
            tournamentType: _tournamentType,
            drawMethod: _drawMethod,
            winPts: _winPts,
            drawPts: _drawPts,
            lossPts: _lossPts,
            selectionCount: _selectionCount,
            city: _locController.text,
            prizes: _prizesController.text,
            seriesLegs: _seriesLegs,
            seriesRounds: _seriesRounds,
            formats: _formats,
          ),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
//  Step 1 — Basic Info
// ─────────────────────────────────────────────────────────────────────────────

class _Step1BasicInfo extends StatelessWidget {
  final TextEditingController nameController, descController, locController;
  final String selectedSport, tournamentType;
  final List<(String, String, IconData)> sports;
  final ValueChanged<String> onSportSelected, onTypeSelected, onChanged;

  const _Step1BasicInfo({
    required this.nameController,
    required this.descController,
    required this.locController,
    required this.selectedSport,
    required this.tournamentType,
    required this.sports,
    required this.onSportSelected,
    required this.onTypeSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        _SectionLabel('Tournament Name *'),
        const SizedBox(height: 8),
        _Field(controller: nameController, hint: 'e.g. Sunday Champions League', onChanged: onChanged),
        const SizedBox(height: 20),
        _SectionLabel('Description'),
        const SizedBox(height: 8),
        _Field(controller: descController, hint: 'e.g. Local tournament for sector 5 clubs', maxLines: 2),
        const SizedBox(height: 20),
        _SectionLabel('City / Region'),
        const SizedBox(height: 8),
        _Field(controller: locController, hint: 'e.g. Mumbai, India'),
        const SizedBox(height: 24),
        _SectionLabel('Sport Type'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: sports.map((s) {
            final isActive = selectedSport == s.$1;
            return GestureDetector(
              onTap: () => onSportSelected(s.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primarySurface : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? AppColors.glassBorder : AppColors.stroke,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(s.$3, color: isActive ? AppColors.primary : AppColors.textTertiary, size: 16),
                    const SizedBox(width: 6),
                    Text(s.$2,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isActive ? AppColors.primary : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (selectedSport.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionLabel('Tournament Type'),
          const SizedBox(height: 12),
          Row(
            children: [
              if (selectedSport != 'efootball')
                _TypeChip(label: 'Teams', value: 'teams', selected: tournamentType, onTap: onTypeSelected),
              if (selectedSport != 'efootball' && (selectedSport == 'badminton' || selectedSport == 'custom'))
                const SizedBox(width: 10),
              if (selectedSport == 'efootball' || selectedSport == 'badminton' || selectedSport == 'custom')
                _TypeChip(label: 'Individual', value: 'individual', selected: tournamentType, onTap: onTypeSelected),
            ],
          ),
        ],
        const SizedBox(height: 8),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _TypeChip extends StatelessWidget {
  final String label, value, selected;
  final ValueChanged<String> onTap;
  const _TypeChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primarySurface : AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? AppColors.glassBorder : AppColors.stroke,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                )),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Step 2 — Format
// ─────────────────────────────────────────────────────────────────────────────

class _Step2Format extends StatelessWidget {
  final String selected;
  final List<(String, String, IconData, String)> formats;
  final ValueChanged<String> onSelect;

  const _Step2Format({required this.selected, required this.formats, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        Text('Choose tournament format',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        ...formats.map((f) {
          final isActive = selected == f.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => onSelect(f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primarySurface : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? AppColors.glassBorder : AppColors.stroke,
                    width: isActive ? 1.5 : 1,
                  ),
                  boxShadow: isActive
                      ? [BoxShadow(color: AppColors.primaryGlow.withAlpha(40), blurRadius: 20, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primaryGlow : AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(f.$3, color: isActive ? AppColors.primary : AppColors.textTertiary, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.$2, style: AppTextStyles.headingSmall),
                          const SizedBox(height: 3),
                          Text(f.$4, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                    if (isActive)
                      Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, size: 13, color: Colors.black),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Step 3 — Scoring Config
// ─────────────────────────────────────────────────────────────────────────────

class _Step3Rules extends StatelessWidget {
  final int winPts, drawPts, lossPts;
  final Map<String, int> seriesLegs;
  final TextEditingController prizesController;
  final List<(String, String)> seriesRounds;
  final ValueChanged<int> onWinChanged, onDrawChanged, onLossChanged;
  final void Function(String, int) onLegsChanged;

  const _Step3Rules({
    required this.winPts,
    required this.drawPts,
    required this.lossPts,
    required this.seriesLegs,
    required this.prizesController,
    required this.seriesRounds,
    required this.onWinChanged,
    required this.onDrawChanged,
    required this.onLossChanged,
    required this.onLegsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        _SectionLabel('Points Config'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _PtsStepper(label: 'Win', value: winPts, color: AppColors.primary, onChanged: onWinChanged)),
            const SizedBox(width: 10),
            Expanded(child: _PtsStepper(label: 'Draw', value: drawPts, color: AppColors.warning, onChanged: onDrawChanged)),
            const SizedBox(width: 10),
            Expanded(child: _PtsStepper(label: 'Loss', value: lossPts, color: AppColors.danger, onChanged: onLossChanged)),
          ],
        ),
        const SizedBox(height: 28),
        _SectionLabel('Series Length (legs per round)'),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: seriesRounds.asMap().entries.map((e) {
              final key = e.value.$1;
              final label = e.value.$2;
              final isLast = e.key == seriesRounds.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
                        _LegsToggle(
                          value: seriesLegs[key] ?? 1,
                          onChanged: (v) => onLegsChanged(key, v),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast) const Divider(height: 1, color: AppColors.divider),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        _SectionLabel('Prizes'),
        const SizedBox(height: 8),
        _Field(controller: prizesController, hint: 'e.g. Trophy + ₹10,000 Shop Voucher'),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _PtsStepper extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  const _PtsStepper({required this.label, required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        children: [
          Text(label, style: AppTextStyles.overline.copyWith(color: color)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepBtn(icon: Icons.remove_rounded, color: color,
                  onTap: value > 0 ? () => onChanged(value - 1) : null),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$value',
                    style: AppTextStyles.headingLarge.copyWith(color: color)),
              ),
              _StepBtn(icon: Icons.add_rounded, color: color, onTap: () => onChanged(value + 1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StepBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: onTap != null ? color.withAlpha(30) : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: onTap != null ? color.withAlpha(70) : AppColors.stroke),
        ),
        child: Icon(icon, size: 14, color: onTap != null ? color : AppColors.textTertiary),
      ),
    );
  }
}

class _LegsToggle extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _LegsToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [1, 2, 3].map((n) {
        final isActive = value == n;
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: GestureDetector(
            onTap: () => onChanged(n),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primarySurface : AppColors.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? AppColors.glassBorder : AppColors.stroke,
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Text('$n',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isActive ? AppColors.primary : AppColors.textTertiary,
                    )),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Step 4 — Select Teams / Players
// ─────────────────────────────────────────────────────────────────────────────

class _Step4Teams extends ConsumerWidget {
  final String tournamentType, sport;
  final Set<String> selectedTeamIds, selectedPlayerIds;
  final void Function(String id, String name) onToggleTeam;
  final void Function(String id, String name, String profileId) onTogglePlayer;

  const _Step4Teams({
    required this.tournamentType,
    required this.sport,
    required this.selectedTeamIds,
    required this.selectedPlayerIds,
    required this.onToggleTeam,
    required this.onTogglePlayer,
  });

  bool get _isIndividual => tournamentType == 'individual';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selCount = _isIndividual ? selectedPlayerIds.length : selectedTeamIds.length;

    final teamsAsync = ref.watch(teamsProvider(sport.isEmpty ? null : sport));
    final playersAsync = ref.watch(playersProvider(null));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Text('$selCount selected',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: selCount >= 2 ? AppColors.primary : AppColors.textTertiary,
                  )),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go(_isIndividual ? '/players' : '/teams'),
                child: Text(
                  _isIndividual ? 'Manage Players' : 'Manage Teams',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        if (selCount < 2)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.warning),
                const SizedBox(width: 6),
                Text('Minimum 2 required',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.warning)),
              ],
            ),
          ),
        Expanded(
          child: _isIndividual
              ? playersAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2),
                  ),
                  error: (e, _) => Center(
                      child: Text('Could not load players',
                          style: AppTextStyles.bodySmall)),
                  data: (players) => _PlayersList(
                    players: players,
                    selectedIds: selectedPlayerIds,
                    onToggle: onTogglePlayer,
                  ),
                )
              : teamsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2),
                  ),
                  error: (e, _) => Center(
                      child: Text('Could not load teams',
                          style: AppTextStyles.bodySmall)),
                  data: (teams) => _TeamsList(
                    teams: teams,
                    sport: sport,
                    selectedIds: selectedTeamIds,
                    onToggle: onToggleTeam,
                  ),
                ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _TeamsList extends StatelessWidget {
  final List<Team> teams;
  final String sport;
  final Set<String> selectedIds;
  final void Function(String id, String name) onToggle;

  const _TeamsList({required this.teams, required this.sport, required this.selectedIds, required this.onToggle});

  Color _teamColor(Team t) {
    if (t.colorHex == null) return AppColors.primary;
    try { return Color(int.parse(t.colorHex!.replaceFirst('#', '0xFF'))); }
    catch (_) { return AppColors.primary; }
  }

  IconData _sportIcon(String s) => switch (s.toLowerCase()) {
    'football'   => Icons.sports_soccer_rounded,
    'cricket'    => Icons.sports_cricket_rounded,
    'basketball' => Icons.sports_basketball_rounded,
    'tennis' || 'badminton' => Icons.sports_tennis_rounded,
    _ => Icons.groups_rounded,
  };

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_rounded, color: AppColors.textTertiary, size: 40),
            const SizedBox(height: 12),
            Text('No ${sport.isEmpty ? "" : sport} teams yet', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/teams'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Text('Go to Teams'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      itemCount: teams.length,
      separatorBuilder: (_, s) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final t = teams[i];
        final isSelected = selectedIds.contains(t.id);
        final c = _teamColor(t);
        final icon = _sportIcon(t.sport);
        return GestureDetector(
          onTap: () => onToggle(t.id, t.name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySurface : AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.glassBorder : AppColors.stroke,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: c.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.withAlpha(60)),
                  ),
                  child: Icon(icon, color: c, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, style: AppTextStyles.headingSmall),
                      Text('${t.playerCount} players',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.stroke,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayersList extends StatelessWidget {
  final List<Player> players;
  final Set<String> selectedIds;
  final void Function(String id, String name, String profileId) onToggle;

  const _PlayersList({required this.players, required this.selectedIds, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_search_rounded, color: AppColors.textTertiary, size: 40),
            const SizedBox(height: 12),
            Text('No players registered yet', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/players'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Text('Go to Players'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      itemCount: players.length,
      separatorBuilder: (_, s) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final p = players[i];
        final isSelected = selectedIds.contains(p.id);
        final avatarColors = [
          const Color(0xFFE53935), const Color(0xFF7B1FA2),
          const Color(0xFF1E88E5), const Color(0xFFFFA000),
          const Color(0xFF43A047), const Color(0xFF00897B),
        ];
        final c = avatarColors[p.name.length % avatarColors.length];
        final parts = p.name.trim().split(' ');
        final initials = parts.length >= 2
            ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
            : p.name.substring(0, 2).toUpperCase();
        final desc = p.role ?? p.sport ?? 'Player';
        return GestureDetector(
          onTap: () => onToggle(p.id, p.name, p.profileId),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySurface : AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.glassBorder : AppColors.stroke,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: c.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.withAlpha(70)),
                  ),
                  child: Center(
                    child: Text(initials,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: c, fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: AppTextStyles.headingSmall),
                      Text(desc,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.stroke),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Step 5 — Draw & Schedule
// ─────────────────────────────────────────────────────────────────────────────

class _Step5Draw extends StatefulWidget {
  final String drawMethod;
  final List<(String, String, IconData, String)> drawOptions;
  final List<String> selectedNames;
  final bool drawCompleted;
  final List<String> drawnOrder;
  final ValueChanged<String> onMethodSelect;
  final ValueChanged<List<String>> onDrawComplete;

  const _Step5Draw({
    required this.drawMethod,
    required this.drawOptions,
    required this.selectedNames,
    required this.drawCompleted,
    required this.drawnOrder,
    required this.onMethodSelect,
    required this.onDrawComplete,
  });

  @override
  State<_Step5Draw> createState() => _Step5DrawState();
}

class _Step5DrawState extends State<_Step5Draw> {
  bool _isAnimating = false;
  List<String> _revealed = [];
  late List<String> _manualOrder;

  @override
  void initState() {
    super.initState();
    _manualOrder = List<String>.from(widget.selectedNames);
  }

  @override
  void didUpdateWidget(_Step5Draw oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drawMethod != widget.drawMethod) {
      _manualOrder = List<String>.from(widget.selectedNames);
    }
  }

  Future<void> _startDraw() async {
    final pool = List<String>.from(widget.selectedNames)..shuffle();
    setState(() {
      _isAnimating = true;
      _revealed = [];
    });
    for (final name in pool) {
      await Future.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;
      setState(() => _revealed.add(name));
    }
    setState(() => _isAnimating = false);
    widget.onDrawComplete(pool);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        Text('How will fixtures be generated?',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        ...widget.drawOptions.map((opt) {
          final isActive = widget.drawMethod == opt.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => widget.onMethodSelect(opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primarySurface : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? AppColors.glassBorder : AppColors.stroke,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primaryGlow : AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(opt.$3, color: isActive ? AppColors.primary : AppColors.textTertiary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(opt.$2, style: AppTextStyles.headingSmall),
                    ),
                    if (opt.$4.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primary.withAlpha(60)),
                        ),
                        child: Text(opt.$4,
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, fontSize: 9)),
                      ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, size: 13, color: Colors.black),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
        if (widget.drawMethod == 'manual') ...[
          const SizedBox(height: 20),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 20),
          Text('Arrange participants in match order',
              style: AppTextStyles.headingSmall),
          const SizedBox(height: 4),
          Text('Drag to reorder — top pair plays first',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: 16),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _manualOrder.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _manualOrder.removeAt(oldIndex);
                _manualOrder.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final name = _manualOrder[index];
              return Padding(
                key: ValueKey(name),
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.drag_handle_rounded,
                          color: AppColors.textTertiary, size: 22),
                      const SizedBox(width: 12),
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Center(
                          child: Text('${index + 1}',
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: AppColors.primary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(name, style: AppTextStyles.headingSmall)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _manualOrder.length >= 2
                  ? () => widget.onDrawComplete(List<String>.from(_manualOrder))
                  : null,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text('CONFIRM ORDER',
                  style: AppTextStyles.labelLarge.copyWith(color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
        if (widget.drawMethod.isNotEmpty && widget.drawMethod != 'manual') ...[
          const SizedBox(height: 20),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 20),
          if (!widget.drawCompleted && !_isAnimating)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: widget.selectedNames.length >= 2 ? _startDraw : null,
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: Text('START DRAW', style: AppTextStyles.labelLarge.copyWith(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          if (_isAnimating || widget.drawCompleted) ...[
            Text('Draw Order',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ...(widget.drawCompleted ? widget.drawnOrder : _revealed).asMap().entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Center(
                          child: Text('${e.key + 1}',
                              style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(e.value, style: AppTextStyles.headingSmall)),
                    ],
                  ),
                ).animate().scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: 400.ms,
                  curve: Curves.elasticOut,
                ).fadeIn(duration: 300.ms),
              );
            }),
            if (_isAnimating)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                ),
              ),
          ],
        ],
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Step 6 — Confirm
// ─────────────────────────────────────────────────────────────────────────────

class _Step6Confirm extends StatelessWidget {
  final String name, sport, format, tournamentType, drawMethod, city, prizes;
  final int winPts, drawPts, lossPts, selectionCount;
  final Map<String, int> seriesLegs;
  final List<(String, String)> seriesRounds;
  final List<(String, String, IconData, String)> formats;

  const _Step6Confirm({
    required this.name,
    required this.sport,
    required this.format,
    required this.tournamentType,
    required this.drawMethod,
    required this.winPts,
    required this.drawPts,
    required this.lossPts,
    required this.selectionCount,
    required this.city,
    required this.prizes,
    required this.seriesLegs,
    required this.seriesRounds,
    required this.formats,
  });

  String _formatLabel(String key) =>
      formats.firstWhere((f) => f.$1 == key, orElse: () => (key, key, Icons.circle, '')).$2;

  String _typeLabel(String t) => switch (t) {
        'individual' => 'Individual',
        'doubles' => 'Doubles',
        _ => 'Teams',
      };

  String _drawLabel(String d) => switch (d) {
        'random' => 'Random Draw',
        'seeded' => 'By Seeding',
        'random_seeded' => 'Random + Seeded',
        'manual' => 'Manual',
        _ => d,
      };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        GlassCardPrimary(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 16),
              Text(name.isEmpty ? 'Unnamed Tournament' : name,
                  style: AppTextStyles.headingLarge, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(sport.isEmpty ? 'No sport selected' : sport.toUpperCase(),
                  style: AppTextStyles.overlinePrimary),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ConfirmRow(label: 'Format', value: format.isEmpty ? '—' : _formatLabel(format)),
              _ConfirmRow(label: 'Type', value: _typeLabel(tournamentType)),
              _ConfirmRow(label: 'Draw Method', value: drawMethod.isEmpty ? '—' : _drawLabel(drawMethod)),
              _ConfirmRow(label: 'Rules', value: 'W $winPts · D $drawPts · L $lossPts'),
              _ConfirmRow(
                  label: 'Total ${tournamentType == "individual" ? "Players" : "Teams"}',
                  value: '$selectionCount'),
              if (city.isNotEmpty) _ConfirmRow(label: 'City', value: city),
              if (prizes.isNotEmpty)
                _ConfirmRow(label: 'Prizes', value: prizes, showDivider: false),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Series Length',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: seriesRounds.map((r) {
                  final legs = seriesLegs[r.$1] ?? 1;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.stroke),
                    ),
                    child: Text('${r.$2}: $legs leg${legs > 1 ? "s" : ""}',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Once created, the tournament will be visible to all users. You can edit details before the first match.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current, total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(total, (i) {
          final done = i < current;
          final active = i == current;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                decoration: BoxDecoration(
                  color: done || active ? AppColors.primary : AppColors.stroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int step;
  final bool canProceed, isLast, isSubmitting;
  final VoidCallback onBack, onNext;

  const _BottomBar({
    required this.step,
    required this.canProceed,
    required this.isLast,
    required this.isSubmitting,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          GhostButton(
            label: step == 0 ? 'Cancel' : 'Back',
            onPressed: onBack,
            width: 110,
            height: 52,
            icon: step > 0 ? Icons.arrow_back_rounded : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PrimaryButton(
              label: isLast ? 'Publish' : 'Continue',
              onPressed: canProceed ? onNext : null,
              isLoading: isSubmitting,
              icon: isLast ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary));
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.bgElevated,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 14 : 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.strokeBright, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label, value;
  final bool showDivider;

  const _ConfirmRow({required this.label, required this.value, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
              Flexible(
                child: Text(value,
                    style: AppTextStyles.labelMedium,
                    textAlign: TextAlign.right),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, color: AppColors.divider),
      ],
    );
  }
}
