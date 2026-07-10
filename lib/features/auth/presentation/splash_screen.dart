import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/hyper_grid_background.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() {
    Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        context.go('/tournaments/dashboard');
      } else {
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: HyperGridBackground(
        showGlowEdge: true,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Trophy / Logo icon with pulsing animation
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(80),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 52,
                  color: AppColors.primary,
                ),
              )
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .scale(
                    begin: const Offset(0.5, 0.5),
                    duration: 800.ms,
                    curve: Curves.elasticOut,
                  )
                  .then(delay: 200.ms)
                  .shimmer(duration: 1200.ms, color: Colors.white24),
              const SizedBox(height: 24),
              // App Title
              Text(
                'TOURNAMENTS',
                style: AppTextStyles.headingLarge.copyWith(
                  letterSpacing: 8,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
              const SizedBox(height: 8),
              // Subtitle
              Text(
                'CHAMPIONSHIP HUB',
                style: AppTextStyles.labelSmall.copyWith(
                  letterSpacing: 4,
                  color: AppColors.primary.withAlpha(180),
                  fontWeight: FontWeight.w600,
                ),
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
            ],
          ),
        ),
      ),
    );
  }
}
