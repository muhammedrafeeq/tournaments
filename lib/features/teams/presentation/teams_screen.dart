import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/team.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/hyper_grid_background.dart';
import '../../../core/widgets/search_bar.dart';
import '../../../core/widgets/team_logo.dart';
import '../../../core/widgets/top_bar.dart';
import '../../../core/widgets/app_button.dart';

class TeamsScreen extends ConsumerStatefulWidget {
  const TeamsScreen({super.key});

  @override
  ConsumerState<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends ConsumerState<TeamsScreen> {
  String _selectedSport = 'All';
  final _searchController = TextEditingController();

  static const _sports = [
    'All', 'Football', 'Cricket', 'Badminton', 'eFootball'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Team> _filter(List<Team> all) {
    return all.where((t) {
      if (_selectedSport != 'All' &&
          t.sport.toLowerCase() != _selectedSport.toLowerCase()) {
        return false;
      }
      final q = _searchController.text.toLowerCase();
      if (q.isNotEmpty && !t.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(teamsProvider(_selectedSport));

    return HyperGridBackground(
      showGlowEdge: true,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: TopBar(),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Teams',
                          style: AppTextStyles.headingLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          async.maybeWhen(
                            data: (list) => '${list.length} registered clubs',
                            orElse: () => 'Loading...',
                          ),
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _CreateTeamBtn(
                      onTap: () => _showCreateTeamSheet(context)),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: SearchInput(
                controller: _searchController,
                hint: 'Search teams...',
                onChanged: (_) => setState(() {}),
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 0, 8),
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 20),
                  itemCount: _sports.length,
                  separatorBuilder: (context, i) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, i) => _SportChip(
                    label: _sports[i],
                    isActive: _selectedSport == _sports[i],
                    onTap: () =>
                        setState(() => _selectedSport = _sports[i]),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
          ),
          async.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: AppColors.textTertiary, size: 40),
                    const SizedBox(height: 12),
                    Text('Could not load teams',
                        style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => ref.invalidate(teamsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (all) {
              final list = _filter(all);
              if (list.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
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
                        Text('No teams found',
                            style: AppTextStyles.headingSmall),
                        const SizedBox(height: 6),
                        Text('Try adjusting filters',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary)),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TeamCard(
                        team: list[i],
                        onTap: () =>
                            context.push('/teams/${list[i].id}'),
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(
                                milliseconds: 200 + i * 60),
                            duration: 400.ms,
                          )
                          .slideY(
                            begin: 0.12,
                            end: 0,
                            delay: Duration(
                                milliseconds: 200 + i * 60),
                            duration: 400.ms,
                            curve: Curves.easeOut,
                          ),
                    ),
                    childCount: list.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCreateTeamSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateTeamSheet(onCreated: () {
        ref.invalidate(teamsProvider);
      }),
    );
  }
}

// ── Team Card ──────────────────────────────────────────────────────────────

class _TeamCard extends StatelessWidget {
  final Team team;
  final VoidCallback onTap;

  const _TeamCard({required this.team, required this.onTap});

  IconData get _icon => switch (team.sport.toLowerCase()) {
        'football' => Icons.sports_soccer_rounded,
        'cricket' => Icons.sports_cricket_rounded,
        'basketball' => Icons.sports_basketball_rounded,
        'tennis' || 'badminton' => Icons.sports_tennis_rounded,
        _ => Icons.groups_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(team.colorHex) ?? shieldColorForName(team.name);
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          TeamLogoWidget(
            name: team.name,
            color: color,
            logoUrl: team.logoUrl,
            size: 52,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.name, style: AppTextStyles.headingSmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(_icon, size: 12, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(team.sport, style: AppTextStyles.bodySmall),
                    const SizedBox(width: 12),
                    const Icon(Icons.person_rounded,
                        size: 12, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text('${team.playerCount} players',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textTertiary, size: 20),
        ],
      ),
    );
  }
}

// ── Create Team Sheet ──────────────────────────────────────────────────────

class _CreateTeamSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateTeamSheet({required this.onCreated});

  @override
  ConsumerState<_CreateTeamSheet> createState() =>
      _CreateTeamSheetState();
}

class _CreateTeamSheetState extends ConsumerState<_CreateTeamSheet> {
  final _nameController = TextEditingController();
  String _selectedSport = 'Football';
  bool _isLoading = false;

  // Logo state
  Color _selectedColor = kShieldColors[0];
  File? _pickedImage;

  static const _sports = [
    'Football', 'Cricket', 'Basketball', 'Tennis', 'Badminton'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (xfile != null) {
      setState(() => _pickedImage = File(xfile.path));
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      String? logoUrl;
      if (_pickedImage != null) {
        logoUrl = await ref.read(teamRepositoryProvider).uploadLogo(_pickedImage!);
      }
      final r = _selectedColor.r.toInt().toRadixString(16).padLeft(2, '0');
      final g = _selectedColor.g.toInt().toRadixString(16).padLeft(2, '0');
      final b = _selectedColor.b.toInt().toRadixString(16).padLeft(2, '0');
      final colorHex = '#$r$g$b'.toUpperCase();
      await ref.read(teamRepositoryProvider).create({
        'name': name,
        'sport': _selectedSport.toLowerCase(),
        'player_count': 0,
        'color_hex': colorHex,
        'logo_url': logoUrl,
      });
      widget.onCreated();
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
    final previewName = _nameController.text.trim().isEmpty
        ? 'TM'
        : _nameController.text.trim();

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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text('Create Team', style: AppTextStyles.headingMedium),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.stroke),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Logo preview + color picker
            Text('Team Logo',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Row(
              children: [
                // Preview
                TeamLogoWidget(
                  name: previewName,
                  color: _selectedColor,
                  logoUrl: _pickedImage != null ? null : null,
                  size: 64,
                ),
                if (_pickedImage != null) ...[
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_pickedImage!,
                        width: 64, height: 64, fit: BoxFit.cover),
                  ),
                ],
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Color swatches
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: kShieldColors.map((c) {
                          final selected = c == _selectedColor && _pickedImage == null;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedColor = c;
                              _pickedImage = null;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: selected
                                    ? Border.all(
                                        color: Colors.white, width: 2.5)
                                    : Border.all(
                                        color: Colors.white24, width: 1),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: c.withAlpha(140),
                                          blurRadius: 8,
                                        )
                                      ]
                                    : null,
                              ),
                              child: selected
                                  ? const Icon(Icons.check_rounded,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      // Upload button
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.stroke),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.upload_rounded,
                                  size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                _pickedImage != null
                                    ? 'Change image'
                                    : 'Upload from device',
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Team Name
            Text('Team Name',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.stroke),
              ),
              child: TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Red Dragons FC',
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
            ),
            const SizedBox(height: 20),

            // Sport
            Text('Sport',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sports
                  .map((s) => _SportChip(
                        label: s,
                        isActive: _selectedSport == s,
                        onTap: () => setState(() => _selectedSport = s),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Create Team',
              onPressed:
                  _nameController.text.trim().isEmpty ? null : _submit,
              isLoading: _isLoading,
              icon: Icons.groups_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared ─────────────────────────────────────────────────────────────────

class _SportChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SportChip(
      {required this.label,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primarySurface
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? AppColors.glassBorder
                : AppColors.stroke,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: isActive
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CreateTeamBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateTeamBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGlow.withAlpha(100),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded,
            size: 18, color: AppColors.textInverse),
      ),
    );
  }
}
