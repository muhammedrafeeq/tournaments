import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AnimationController _tabCtrl;
  late final Animation<double> _tabAnim;

  @override
  void initState() {
    super.initState();
    _tabCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _tabAnim = CurvedAnimation(parent: _tabCtrl, curve: Curves.easeOut);
    _tabCtrl.forward();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _switchTab(bool login) {
    setState(() => _isLogin = login);
    _tabCtrl.forward(from: 0);
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authRepositoryProvider);
      if (_isLogin) {
        await auth.signInWithEmail(email, password);
      } else {
        await auth.signUpWithEmail(
          email: email,
          password: password,
          username: _nameController.text.trim(),
        );
      }
      if (mounted) context.go('/tournaments');
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('AuthException: ', '')),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          // ── wider side padding ────────────────────────────────────────
          padding: const EdgeInsets.symmetric(horizontal: 28),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 52),
              _buildLogo(),
              const SizedBox(height: 36),
              _buildTabRow(),
              const SizedBox(height: 28),
              _buildFields(),
              const SizedBox(height: 20),
              _buildSubmitButton(),
              const SizedBox(height: 16),
              if (_isLogin) _buildForgotPassword(),
              const SizedBox(height: 36),
              _buildDivider(),
              const SizedBox(height: 16),
              _buildSocialRow(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Logo / heading ────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: const Icon(Icons.emoji_events_rounded,
              color: AppColors.primary, size: 28),
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .scale(
                begin: const Offset(0.7, 0.7),
                duration: 500.ms,
                curve: Curves.easeOutBack),
        const SizedBox(height: 20),
        Text(
          _isLogin ? 'Welcome\nback.' : 'Create your\naccount.',
          style: AppTextStyles.displaySmall.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
        const SizedBox(height: 6),
        Text(
          _isLogin
              ? 'Sign in to manage your tournaments.'
              : 'Join and start competing today.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textTertiary),
        ).animate().fadeIn(delay: 180.ms, duration: 400.ms),
      ],
    );
  }

  // ── Tab toggle ────────────────────────────────────────────────────────────

  Widget _buildTabRow() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          _TabBtn(label: 'Sign In', active: _isLogin,
              onTap: () => _switchTab(true)),
          _TabBtn(label: 'Register', active: !_isLogin,
              onTap: () => _switchTab(false)),
        ],
      ),
    ).animate().fadeIn(delay: 250.ms, duration: 400.ms);
  }

  // ── Fields ────────────────────────────────────────────────────────────────

  Widget _buildFields() {
    return AnimatedBuilder(
      animation: _tabAnim,
      builder: (_, child) => Opacity(
        opacity: _tabAnim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - _tabAnim.value)),
          child: child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isLogin) ...[
            _Field(
              label: 'Full Name',
              controller: _nameController,
              hint: 'Enter your full name',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 16),
          ],
          _Field(
            label: 'Email address',
            controller: _emailController,
            hint: 'you@example.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _Field(
            label: 'Password',
            controller: _passwordController,
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePassword,
            suffix: GestureDetector(
              onTap: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    return PrimaryButton(
      label: _isLogin ? 'Sign In' : 'Create Account',
      onPressed: _handleSubmit,
      isLoading: _isLoading,
      icon: _isLogin ? Icons.login_rounded : Icons.person_add_rounded,
    ).animate().fadeIn(delay: 350.ms, duration: 400.ms);
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () {},
        child: Text(
          'Forgot password?',
          style: AppTextStyles.labelSmall
              .copyWith(color: AppColors.primary),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }

  // ── Divider ───────────────────────────────────────────────────────────────

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.stroke)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('or continue with',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textTertiary)),
        ),
        Expanded(child: Container(height: 1, color: AppColors.stroke)),
      ],
    ).animate().fadeIn(delay: 450.ms, duration: 400.ms);
  }

  // ── Social ────────────────────────────────────────────────────────────────

  Widget _buildSocialRow() {
    return Row(
      children: [
        Expanded(
          child: _SocialBtn(
            label: 'Google',
            icon: Icons.g_mobiledata_rounded,
            onTap: _handleSubmit,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialBtn(
            label: 'Apple',
            icon: Icons.apple_rounded,
            onTap: _handleSubmit,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms, duration: 400.ms);
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────

class _Field extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final Widget? suffix;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.suffix,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          widget.label,
          style: AppTextStyles.labelSmall.copyWith(
            color: _focused ? AppColors.primary : AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        // Input container
        Focus(
          onFocusChange: (v) => setState(() => _focused = v),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: _focused
                  ? AppColors.bgElevated
                  : AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focused ? AppColors.primary : AppColors.stroke,
                width: _focused ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  widget.icon,
                  size: 20,
                  color: _focused
                      ? AppColors.primary
                      : AppColors.textTertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    obscureText: widget.obscure,
                    keyboardType: widget.keyboardType,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textTertiary),
                      // Override every border/fill the theme injects
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (widget.suffix != null) widget.suffix!,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: double.infinity,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? AppColors.bgElevated : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: active
                  ? AppColors.textPrimary
                  : AppColors.textTertiary,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SocialBtn(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(label,
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
