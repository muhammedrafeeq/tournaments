import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/player.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/hyper_grid_background.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../core/widgets/search_bar.dart';
import '../../../core/widgets/team_logo.dart';
import '../../../core/widgets/top_bar.dart';
import '../../../core/widgets/app_button.dart';

class PlayersScreen extends ConsumerStatefulWidget {
  const PlayersScreen({super.key});

  @override
  ConsumerState<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends ConsumerState<PlayersScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Player> _filter(List<Player> all) {
    final q = _searchController.text.toLowerCase();
    if (q.isEmpty) return all;
    return all.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(playersProvider(null));

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
                          'Players',
                          style: AppTextStyles.headingLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          async.maybeWhen(
                            data: (list) => '${list.length} registered athletes',
                            orElse: () => 'Loading...',
                          ),
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _AddPlayerBtn(
                      onTap: () => _showAddSheet(context)),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: SearchInput(
                controller: _searchController,
                hint: 'Search players...',
                onChanged: (_) => setState(() {}),
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
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
                    Text('Could not load players',
                        style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(playersProvider),
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
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: const Icon(
                              Icons.person_search_rounded,
                              color: AppColors.primary,
                              size: 36),
                        ),
                        const SizedBox(height: 16),
                        Text('No players found',
                            style: AppTextStyles.headingSmall),
                        const SizedBox(height: 6),
                        Text('Try a different search',
                            style: AppTextStyles.bodySmall
                                .copyWith(
                                    color:
                                        AppColors.textTertiary)),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                );
              }
              return SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(20, 12, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PlayerCard(
                        player: list[i],
                        onTap: () => _showEditSheet(context, list[i]),
                        onDelete: () => _confirmDeletePlayer(list[i]),
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(
                                milliseconds: 200 + i * 50),
                            duration: 400.ms,
                          )
                          .slideY(
                            begin: 0.1,
                            end: 0,
                            delay: Duration(
                                milliseconds: 200 + i * 50),
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

  void _confirmDeletePlayer(Player player) async {
    // Always check by player ID — re-fetches team_id from DB in case local model is stale
    final inActive = await ref
        .read(teamRepositoryProvider)
        .isPlayerInActiveTournament(player.id);
    if (!mounted) return;
    if (inActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete a player whose team is in an upcoming or live tournament.'),
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
        title: Text('Delete Player', style: AppTextStyles.headingSmall),
        content: Text('Are you sure you want to delete player "${player.name}"?', style: AppTextStyles.bodySmall),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(playerRepositoryProvider).delete(player.id);
                ref.invalidate(playersProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Player deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete player: $e')),
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

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPlayerSheet(onAdded: () {
        ref.invalidate(playersProvider);
      }),
    );
  }

  void _showEditSheet(BuildContext context, Player player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPlayerSheet(
        player: player,
        onUpdated: () {
          ref.invalidate(playersProvider);
        },
      ),
    );
  }
}

// ── Player Card ────────────────────────────────────────────────────────────

class _PlayerCard extends StatelessWidget {
  final Player player;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PlayerCard({
    required this.player,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = avatarColorForName(player.name);
    final role = player.role ?? player.sport ?? 'Player';
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          PlayerAvatarWidget(
            name: player.name,
            color: color,
            avatarUrl: player.avatarUrl,
            size: 48,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name,
                    style: AppTextStyles.headingSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(role,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (player.jerseyNumber != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('#${player.jerseyNumber}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.primary)),
            ),
          ],
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger, size: 20),
            onPressed: onDelete,
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textTertiary, size: 20),
        ],
      ),
    );
  }
}

// ── Add Player Sheet ───────────────────────────────────────────────────────

class _AddPlayerSheet extends ConsumerStatefulWidget {
  final VoidCallback onAdded;
  const _AddPlayerSheet({required this.onAdded});

  @override
  ConsumerState<_AddPlayerSheet> createState() =>
      _AddPlayerSheetState();
}

class _AddPlayerSheetState extends ConsumerState<_AddPlayerSheet> {
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  bool _isLoading = false;
  Color _selectedColor = kShieldColors[0];
  File? _pickedImage;

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
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
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception('Not signed in');
      String? avatarUrl;
      if (_pickedImage != null) {
        avatarUrl = await ref.read(playerRepositoryProvider).uploadAvatar(_pickedImage!);
      }
      await ref.read(playerRepositoryProvider).create({
        'profile_id': user.id,
        'name': name,
        'role': _roleController.text.trim().isEmpty ? null : _roleController.text.trim(),
        'avatar_url': avatarUrl,
      });
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final previewName = _nameController.text.trim().isEmpty ? '?' : _nameController.text.trim();
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
            Row(
              children: [
                Text('Add Player', style: AppTextStyles.headingMedium),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.stroke),
                    ),
                    child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Photo', style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            _AvatarPicker(
              previewName: previewName,
              selectedColor: _selectedColor,
              pickedImage: _pickedImage,
              onColorSelected: (c) => setState(() { _selectedColor = c; _pickedImage = null; }),
              onPickImage: _pickImage,
            ),
            const SizedBox(height: 20),
            _SheetField(
              label: 'Full Name',
              controller: _nameController,
              hint: 'e.g. Marcus Rivera',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _SheetField(
              label: 'Role / Position',
              controller: _roleController,
              hint: 'e.g. Forward, Batsman…',
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Add Player',
              icon: Icons.person_add_rounded,
              isLoading: _isLoading,
              onPressed: _nameController.text.trim().isEmpty ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const _SheetField({
    required this.label,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
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
            controller: controller,
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
        ),
      ],
    );
  }
}

class _AddPlayerBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPlayerBtn({required this.onTap});

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
        child: const Icon(Icons.person_add_rounded,
            size: 17, color: AppColors.textInverse),
      ),
    );
  }
}

// ── Edit Player Sheet ──────────────────────────────────────────────────────

class _EditPlayerSheet extends ConsumerStatefulWidget {
  final Player player;
  final VoidCallback onUpdated;
  const _EditPlayerSheet({required this.player, required this.onUpdated});

  @override
  ConsumerState<_EditPlayerSheet> createState() => _EditPlayerSheetState();
}

class _EditPlayerSheetState extends ConsumerState<_EditPlayerSheet> {
  late final _nameController = TextEditingController(text: widget.player.name);
  late final _roleController = TextEditingController(text: widget.player.role);
  late final _jerseyController = TextEditingController(text: widget.player.jerseyNumber?.toString() ?? '');
  bool _isLoading = false;
  Color _selectedColor = kShieldColors[0];
  File? _pickedImage;
  bool _clearAvatar = false;

  @override
  void initState() {
    super.initState();
    _selectedColor = avatarColorForName(widget.player.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _jerseyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final xfile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (xfile != null) {
      setState(() { _pickedImage = File(xfile.path); _clearAvatar = false; });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final jerseyNum = int.tryParse(_jerseyController.text.trim());
      String? avatarUrl = widget.player.avatarUrl;
      if (_pickedImage != null) {
        avatarUrl = await ref.read(playerRepositoryProvider).uploadAvatar(_pickedImage!);
      } else if (_clearAvatar) {
        avatarUrl = null;
      }
      await ref.read(playerRepositoryProvider).update(widget.player.id, {
        'name': name,
        'role': _roleController.text.trim().isEmpty ? null : _roleController.text.trim(),
        'jersey_number': _jerseyController.text.trim().isEmpty ? null : jerseyNum,
        'avatar_url': avatarUrl,
      });
      widget.onUpdated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final previewName = _nameController.text.trim().isEmpty ? widget.player.name : _nameController.text.trim();
    final existingUrl = (_clearAvatar || _pickedImage != null) ? null : widget.player.avatarUrl;
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
            Row(
              children: [
                Text('Edit Player Details', style: AppTextStyles.headingMedium),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.stroke),
                    ),
                    child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Photo', style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            _AvatarPicker(
              previewName: previewName,
              selectedColor: _selectedColor,
              pickedImage: _pickedImage,
              existingAvatarUrl: existingUrl,
              onColorSelected: (c) => setState(() { _selectedColor = c; _pickedImage = null; _clearAvatar = true; }),
              onPickImage: _pickImage,
            ),
            const SizedBox(height: 20),
            _SheetField(
              label: 'Full Name',
              controller: _nameController,
              hint: 'e.g. Marcus Rivera',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _SheetField(
              label: 'Role / Position',
              controller: _roleController,
              hint: 'e.g. Forward, Batsman…',
            ),
            const SizedBox(height: 16),
            _SheetField(
              label: 'Jersey Number',
              controller: _jerseyController,
              hint: 'e.g. 7, 10, 23',
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Save Changes',
              icon: Icons.save_rounded,
              isLoading: _isLoading,
              onPressed: _nameController.text.trim().isEmpty ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar Picker (shared between Add and Edit sheets) ─────────────────────

class _AvatarPicker extends StatelessWidget {
  final String previewName;
  final Color selectedColor;
  final File? pickedImage;
  final String? existingAvatarUrl;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onPickImage;

  const _AvatarPicker({
    required this.previewName,
    required this.selectedColor,
    required this.pickedImage,
    required this.onColorSelected,
    required this.onPickImage,
    this.existingAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Preview
        if (pickedImage != null)
          ClipOval(
            child: Image.file(pickedImage!, width: 60, height: 60, fit: BoxFit.cover),
          )
        else
          PlayerAvatarWidget(
            name: previewName,
            color: selectedColor,
            avatarUrl: existingAvatarUrl,
            size: 60,
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
                  final selected = c == selectedColor && pickedImage == null && existingAvatarUrl == null;
                  return GestureDetector(
                    onTap: () => onColorSelected(c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 28,
                      height: 28,
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
                          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
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
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
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
