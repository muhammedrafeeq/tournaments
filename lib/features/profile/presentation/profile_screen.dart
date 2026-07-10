import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/profile.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/hyper_grid_background.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: HyperGridBackground(
        showGlowEdge: true,
        child: profileAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load profile',
                    style: AppTextStyles.bodyMedium),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.invalidate(currentProfileProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (profile) => _ProfileBody(profile: profile),
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  final Profile? profile;
  const _ProfileBody({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = profile?.username ?? 'Player';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildTopBar(context, ref, name)),
        SliverToBoxAdapter(
            child: _buildAvatarSection(name)),
        SliverToBoxAdapter(child: _buildStatsRow(context, ref)),
        SliverToBoxAdapter(child: _buildSettings(context, ref)),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, WidgetRef ref, String name) {
    final topPad = MediaQuery.of(context).padding.top;
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 0),
      child: Row(
        children: [
          if (canPop) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 15, color: AppColors.textPrimary),
              ),
            ),
          ],
          Text('Profile', style: AppTextStyles.headingLarge),
          const Spacer(),
          _IconBtn(
            icon: Icons.settings_outlined,
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _EditProfileSheet(
                  currentUsername: name,
                  onSaved: () {
                    ref.invalidate(currentProfileProvider);
                  },
                ),
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildAvatarSection(String name) {
    final initials = () {
      final parts = name.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
    }();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        children: [
          Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A3D25), Color(0xFF0D2218)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.stroke, width: 2),
            ),
            child: Center(
              child: Text(
                initials,
                style: AppTextStyles.headingLarge
                    .copyWith(color: AppColors.primary),
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 100.ms, duration: 500.ms)
              .scale(
                begin: const Offset(0.8, 0.8),
                delay: 100.ms,
                duration: 500.ms,
                curve: Curves.elasticOut,
              ),
          const SizedBox(height: 16),
          Text(name, style: AppTextStyles.headingLarge)
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms),
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Text('@${name.toLowerCase().replaceAll(' ', '')}',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.primary)),
          ).animate().fadeIn(delay: 280.ms, duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(profileStatsProvider);

    return statsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            Expanded(child: _StatCardPlaceholder(label: 'Events')),
            SizedBox(width: 12),
            Expanded(child: _StatCardPlaceholder(label: 'Teams')),
          ],
        ),
      ),
      error: (err, st) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            Expanded(child: _StatCardPlaceholder(label: 'Events')),
            SizedBox(width: 12),
            Expanded(child: _StatCardPlaceholder(label: 'Teams')),
          ],
        ),
      ),
      data: (stats) {
        final items = [
          (stats.events.toString(), 'Events', Icons.workspace_premium_rounded),
          (stats.teams.toString(), 'Teams', Icons.groups_rounded),
        ];
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final s = e.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 1 ? 12 : 0),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 8),
                    child: Column(
                      children: [
                        Icon(s.$3, size: 18, color: AppColors.primary),
                        const SizedBox(height: 8),
                        Text(s.$1,
                            style: AppTextStyles.headingMedium),
                        const SizedBox(height: 2),
                        Text(s.$2,
                            style: AppTextStyles.bodySmall,
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ).animate().fadeIn(
                        delay: Duration(
                            milliseconds: 350 + i * 60),
                        duration: 350.ms,
                      ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSettings(BuildContext context, WidgetRef ref) {
    final items = [
      (
        Icons.notifications_outlined,
        'Notifications',
        AppColors.textSecondary,
        () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Notifications'),
              content: const Text('Push notifications coming soon.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      ),
      (
        Icons.lock_outline_rounded,
        'Privacy & Security',
        AppColors.textSecondary,
        () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Privacy & Security'),
              content: const Text(
                  'Your data is protected with Supabase Row Level Security. Only you can modify your profile and teams.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      ),
      (
        Icons.help_outline_rounded,
        'Help & Support',
        AppColors.textSecondary,
        () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Help & Support'),
              content: const Text(
                  'For support, contact: support@tournments.app\n\nApp version: 1.0.0'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      ),
      (
        Icons.logout_rounded,
        'Sign Out',
        AppColors.danger,
        () async {
          await ref.read(authRepositoryProvider).signOut();
          if (context.mounted) context.go('/login');
        }
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Settings'),
          const SizedBox(height: 12),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: items.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                final isLast = i == items.length - 1;
                return Column(
                  children: [
                    GestureDetector(
                      onTap: item.$4,
                      child: Container(
                        color: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 15),
                        child: Row(
                          children: [
                            Icon(item.$1, size: 20, color: item.$3),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(item.$2,
                                  style: AppTextStyles.labelMedium
                                      .copyWith(color: item.$3)),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                size: 18,
                                color: isLast
                                    ? AppColors.danger.withAlpha(120)
                                    : AppColors.textTertiary),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      const Divider(
                          height: 1, color: AppColors.divider),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 400.ms);
  }
}

class _StatCardPlaceholder extends StatelessWidget {
  final String label;
  const _StatCardPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          const SizedBox(height: 18),
          const SizedBox(height: 8),
          Text('—', style: AppTextStyles.headingMedium),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  final String currentUsername;
  final VoidCallback onSaved;

  const _EditProfileSheet({
    required this.currentUsername,
    required this.onSaved,
  });

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentUsername);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newUsername = _controller.text.trim();
    if (newUsername.isEmpty) return;

    setState(() => _saving = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'username': newUsername})
            .eq('id', user.id);
      }
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomPad),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.stroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Edit Profile', style: AppTextStyles.headingMedium),
          const SizedBox(height: 20),
          Text('Username', style: AppTextStyles.labelSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.bg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.stroke),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.stroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _saving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.stroke),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Cancel',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Save',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.headingSmall),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }
}
