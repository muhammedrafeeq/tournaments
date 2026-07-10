import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final bool transparent;
  final double elevation;

  const TopBar({
    super.key,
    this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBack = false,
    this.transparent = false,
    this.elevation = 0,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final effectiveTitle = showBack ? (title ?? '') : 'TOURNAMENTS';

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: transparent
              ? null
              : BoxDecoration(
                  color: AppColors.bgSurface.withAlpha(160),
                  border: const Border(
                    bottom: BorderSide(color: AppColors.divider, width: 1),
                  ),
                ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    if (showBack)
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
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
                      )
                    else if (leading != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: leading!,
                      ),
                    Expanded(
                      child: showBack
                          ? Text(
                              effectiveTitle,
                              style: AppTextStyles.headingMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : const Align(
                              alignment: Alignment.centerLeft,
                              child: Icon(
                                Icons.emoji_events_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                    ),
                    if (actions != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actions!
                            .map((a) => Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: a,
                                ))
                            .toList(),
                      )
                    else if (!showBack)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          NotifBtn(),
                          SizedBox(width: 10),
                          ProfileAvatar(),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final initials = profileAsync.maybeWhen(
      data: (p) {
        final name = p?.username ?? 'P';
        final parts = name.trim().split(' ');
        if (parts.length >= 2) {
          return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
        }
        return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
      },
      orElse: () => 'P',
    );

    return GestureDetector(
      onTap: () => context.push('/profile'),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A3D25), Color(0xFF0D2218)],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary.withAlpha(120), width: 1.5),
        ),
        child: Center(
          child: Text(
            initials,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

class NotifBtn extends StatelessWidget {
  const NotifBtn({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppColors.stroke),
          ),
          child: const Icon(Icons.notifications_rounded,
              size: 18, color: AppColors.textSecondary),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.danger,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
