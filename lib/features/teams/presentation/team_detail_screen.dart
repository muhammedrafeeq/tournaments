import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/player.dart';
import '../../../core/models/team.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/hyper_grid_background.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../core/widgets/team_logo.dart';
import '../../../core/widgets/app_button.dart';

class TeamDetailScreen extends ConsumerWidget {
  final String id;
  const TeamDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamDetailProvider(id));
    final playersAsync = ref.watch(teamPlayersProvider(id));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: teamAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load team',
                  style: AppTextStyles.bodyMedium),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    ref.invalidate(teamDetailProvider(id)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (team) {
          if (team == null) {
            return Center(
                child: Text('Team not found',
                    style: AppTextStyles.bodyMedium));
          }
          return _TeamBody(
            team: team,
            playersAsync: playersAsync,
            onRefresh: () {
              ref.invalidate(teamDetailProvider(id));
              ref.invalidate(teamPlayersProvider(id));
              ref.invalidate(teamsProvider);
            },
          );
        },
      ),
    );
  }
}

class _TeamBody extends ConsumerStatefulWidget {
  final Team team;
  final AsyncValue<List<Player>> playersAsync;
  final VoidCallback onRefresh;

  const _TeamBody({
    required this.team,
    required this.playersAsync,
    required this.onRefresh,
  });

  @override
  ConsumerState<_TeamBody> createState() => _TeamBodyState();
}

class _TeamBodyState extends ConsumerState<_TeamBody> {
  void _openAddMember() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMemberSheet(
        team: widget.team,
        onAdded: widget.onRefresh,
      ),
    );
  }

  void _removeMember(String playerId) async {
    final repo = ref.read(teamRepositoryProvider);
    final inActive = await repo.isTeamInActiveTournament(widget.team.id);
    if (!mounted) return;
    if (inActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove a player while the team is in an upcoming or live tournament.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    try {
      await repo.removePlayer(playerId);
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _confirmDeleteTeam() async {
    final repo = ref.read(teamRepositoryProvider);
    final inActive = await repo.isTeamInActiveTournament(widget.team.id);
    if (!mounted) return;

    if (inActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete a team enrolled in an upcoming or live tournament.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Team', style: AppTextStyles.headingSmall),
        content: Text('Are you sure you want to delete team "${widget.team.name}"?', style: AppTextStyles.bodySmall),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await repo.delete(widget.team.id);
                ref.invalidate(teamsProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Team deleted successfully')),
                  );
                  context.pop();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete team: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color get _teamColor {
    if (widget.team.colorHex == null) return AppColors.primary;
    try {
      return Color(int.parse(
          widget.team.colorHex!.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  IconData get _sportIcon =>
      switch (widget.team.sport.toLowerCase()) {
        'football' => Icons.sports_soccer_rounded,
        'cricket' => Icons.sports_cricket_rounded,
        'basketball' => Icons.sports_basketball_rounded,
        'tennis' || 'badminton' =>
          Icons.sports_tennis_rounded,
        _ => Icons.groups_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final players = widget.playersAsync.maybeWhen(
      data: (p) => p,
      orElse: () => <Player>[],
    );
    final isLoadingPlayers =
        widget.playersAsync is AsyncLoading;

    return HyperGridBackground(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              team: widget.team,
              teamColor: _teamColor,
              sportIcon: _sportIcon,
              memberCount: players.length,
              onBack: () => context.pop(),
              onAdd: _openAddMember,
              onDelete: _confirmDeleteTeam,
            ),
          ),
          if (isLoadingPlayers)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
            )
          else if (players.isEmpty)
            SliverFillRemaining(
              child: _EmptySquad(onAdd: _openAddMember),
            )
          else
            SliverPadding(
              padding:
                  const EdgeInsets.fromLTRB(20, 8, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: 12),
                    child: _MemberCard(
                      player: players[i],
                      onRemove: () =>
                          _confirmRemove(players[i]),
                    )
                        .animate()
                        .fadeIn(
                          delay: Duration(
                              milliseconds: 100 + i * 50),
                          duration: 350.ms,
                        )
                        .slideY(
                          begin: 0.08,
                          end: 0,
                          delay: Duration(
                              milliseconds: 100 + i * 50),
                          duration: 350.ms,
                          curve: Curves.easeOut,
                        ),
                  ),
                  childCount: players.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmRemove(Player player) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2E22),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Member',
            style: AppTextStyles.headingSmall),
        content: Text(
          'Remove ${player.name} from the squad?',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _removeMember(player.id);
            },
            child: Text('Remove',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Team team;
  final Color teamColor;
  final IconData sportIcon;
  final int memberCount;
  final VoidCallback onBack, onAdd, onDelete;

  const _Header({
    required this.team,
    required this.teamColor,
    required this.sportIcon,
    required this.memberCount,
    required this.onBack,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return GlassCardPrimary(
      padding:
          EdgeInsets.fromLTRB(20, topPadding + 12, 20, 20),
      borderRadius: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(11),
                    border:
                        Border.all(color: AppColors.stroke),
                  ),
                  child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 18,
                      color: AppColors.textSecondary),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGlow
                            .withAlpha(100),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                      Icons.person_add_rounded,
                      size: 17,
                      color: Colors.black),
                ),
              ),
              const SizedBox(width: 10),
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'delete') {
                    onDelete();
                  }
                },
                color: AppColors.bgCard,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.stroke)),
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded, color: AppColors.danger, size: 18),
                        const SizedBox(width: 8),
                        Text('Delete Team',
                            style: TextStyle(color: AppColors.danger)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: const Icon(Icons.more_vert_rounded,
                      size: 18, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              TeamLogoWidget(
                name: team.name,
                color: teamColor,
                logoUrl: team.logoUrl,
                size: 64,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(team.name,
                        style: AppTextStyles.headingLarge),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(sportIcon,
                            size: 12,
                            color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(team.sport,
                            style: AppTextStyles.bodySmall
                                .copyWith(
                                    color: AppColors
                                        .textTertiary)),
                        const SizedBox(width: 12),
                        const Icon(Icons.person_rounded,
                            size: 12,
                            color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text('$memberCount members',
                            style: AppTextStyles.bodySmall
                                .copyWith(
                                    color: AppColors
                                        .textTertiary)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Squad', style: AppTextStyles.headingSmall),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ── Member Card ────────────────────────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  final Player player;
  final VoidCallback onRemove;

  const _MemberCard({required this.player, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final color = avatarColorForName(player.name);
    final role = player.role ?? 'Player';
    final number = player.jerseyNumber;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              PlayerAvatarWidget(
                name: player.name,
                color: color,
                avatarUrl: player.avatarUrl,
                size: 48,
              ),
              if (number != null)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.stroke),
                    ),
                    child: Text(
                      '#$number',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.primary, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name, style: AppTextStyles.headingSmall),
                const SizedBox(height: 3),
                Text(role,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.danger.withAlpha(20),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.danger.withAlpha(50)),
              ),
              child: const Icon(Icons.person_remove_rounded,
                  size: 15, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty Squad ────────────────────────────────────────────────────────────

class _EmptySquad extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptySquad({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.groups_rounded,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text('No squad members yet',
              style: AppTextStyles.headingSmall),
          const SizedBox(height: 6),
          Text('Add your first player to get started',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Add Member',
            icon: Icons.person_add_rounded,
            onPressed: onAdd,
            width: 180,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ── Add Member Sheet ───────────────────────────────────────────────────────

class _AddMemberSheet extends ConsumerStatefulWidget {
  final Team team;
  final VoidCallback onAdded;
  const _AddMemberSheet(
      {required this.team, required this.onAdded});

  @override
  ConsumerState<_AddMemberSheet> createState() =>
      _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<_AddMemberSheet> {
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  late String _role;
  late final List<String> _roles;
  bool _isLoading = false;
  Color _selectedColor = kShieldColors[0];
  File? _pickedImage;

  List<String> _getRolesForSport(String sport) {
    final s = sport.toLowerCase();
    if (s == 'football' || s == 'efootball') {
      return ['Forward', 'Midfielder', 'Defender', 'Goalkeeper', 'Substitute'];
    } else if (s == 'cricket') {
      return ['Batsman', 'Bowler', 'All-Rounder', 'Wicketkeeper', 'Substitute'];
    } else if (s == 'badminton' || s == 'tennis') {
      return ['Singles Player', 'Doubles Player', 'Substitute'];
    } else if (s == 'chess') {
      return ['Player', 'Coach'];
    } else {
      return ['Player', 'Substitute'];
    }
  }

  @override
  void initState() {
    super.initState();
    _roles = _getRolesForSport(widget.team.sport);
    _role = _roles.first;
  }

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final xfile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (xfile != null) setState(() => _pickedImage = File(xfile.path));
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception('Not signed in');
      String? avatarUrl;
      if (_pickedImage != null) {
        avatarUrl = await ref.read(playerRepositoryProvider).uploadAvatar(_pickedImage!);
      }
      await ref.read(teamRepositoryProvider).addPlayer({
        'profile_id': user.id,
        'team_id': widget.team.id,
        'name': _nameController.text.trim(),
        'sport': widget.team.sport,
        'role': _role,
        'jersey_number': int.tryParse(_numberController.text.trim()),
        'avatar_url': avatarUrl,
      });
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

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
          colors: [
            Color(0xFF1E2E22),
            Color(0xFF162018),
            Color(0xFF111A14)
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.stroke),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Add Squad Member',
                    style: AppTextStyles.headingMedium),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color: AppColors.stroke),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 16,
                        color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Photo',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            _MemberAvatarPicker(
              previewName: _nameController.text.trim().isEmpty
                  ? '?'
                  : _nameController.text.trim(),
              selectedColor: _selectedColor,
              pickedImage: _pickedImage,
              onColorSelected: (c) => setState(() {
                _selectedColor = c;
                _pickedImage = null;
              }),
              onPickImage: _pickImage,
            ),
            const SizedBox(height: 20),
            Text('Full Name',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            _SheetField(
              controller: _nameController,
              hint: 'e.g. Marcus Rivera',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text('Jersey Number',
                style: AppTextStyles.labelMedium
                    .copyWith(
                        color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            _SheetField(
              controller: _numberController,
              hint: 'e.g. 10',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Text('Role / Position',
                style: AppTextStyles.labelMedium
                    .copyWith(
                        color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _roles
                  .map((r) => _RoleChip(
                        label: r,
                        isActive: _role == r,
                        onTap: () =>
                            setState(() => _role = r),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Add to Squad',
              icon: Icons.person_add_rounded,
              isLoading: _isLoading,
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _SheetField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: AppTextStyles.bodyMedium
            .copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textTertiary),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _RoleChip(
      {required this.label,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primarySurface
              : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppColors.glassBorder
                : AppColors.stroke,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isActive
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Member Avatar Picker ───────────────────────────────────────────────────

class _MemberAvatarPicker extends StatelessWidget {
  final String previewName;
  final Color selectedColor;
  final File? pickedImage;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onPickImage;

  const _MemberAvatarPicker({
    required this.previewName,
    required this.selectedColor,
    required this.pickedImage,
    required this.onColorSelected,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (pickedImage != null)
          ClipOval(
            child: Image.file(pickedImage!, width: 56, height: 56, fit: BoxFit.cover),
          )
        else
          PlayerAvatarWidget(
            name: previewName,
            color: selectedColor,
            size: 56,
          ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kShieldColors.map((c) {
                  final selected = c == selectedColor && pickedImage == null;
                  return GestureDetector(
                    onTap: () => onColorSelected(c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.white, width: 2.5)
                            : Border.all(color: Colors.white24, width: 1),
                        boxShadow: selected
                            ? [BoxShadow(color: c.withAlpha(140), blurRadius: 8)]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onPickImage,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.upload_rounded, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        pickedImage != null ? 'Change photo' : 'Upload from device',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
