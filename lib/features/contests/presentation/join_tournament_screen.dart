import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/hyper_grid_background.dart';
import '../../../core/widgets/top_bar.dart';
import '../../../core/widgets/app_button.dart';

class JoinTournamentScreen extends ConsumerStatefulWidget {
  const JoinTournamentScreen({super.key});

  @override
  ConsumerState<JoinTournamentScreen> createState() =>
      _JoinTournamentScreenState();
}

class _JoinTournamentScreenState extends ConsumerState<JoinTournamentScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 6) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tournament =
          await ref.read(tournamentRepositoryProvider).fetchByInviteCode(code);

      if (!mounted) return;

      if (tournament == null) {
        setState(() {
          _errorMessage = 'No tournament found with that code';
          _isLoading = false;
        });
        return;
      }

      context.push('/tournaments/${tournament.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: TopBar(title: 'Join Tournament', showBack: true),
      body: HyperGridBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.stroke),
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: const Icon(
                      Icons.vpn_key_rounded,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Enter Invite Code',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ask the tournament organiser for the 6-letter code',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headingMedium.copyWith(
                      color: AppColors.textPrimary,
                      letterSpacing: 4,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'XXXXXX',
                      hintStyle: AppTextStyles.headingMedium.copyWith(
                        color: AppColors.textTertiary,
                        letterSpacing: 4,
                      ),
                      filled: true,
                      fillColor: AppColors.bg,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.stroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (_) {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _codeController,
                    builder: (context, value, _) {
                      return PrimaryButton(
                        label: 'Find Tournament',
                        isLoading: _isLoading,
                        onPressed: value.text.length >= 6 ? _submit : null,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
