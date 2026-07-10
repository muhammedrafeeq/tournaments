import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _tabs = [
    _NavTab(icon: Icons.home_rounded, label: 'Home', path: '/tournaments/dashboard'),
    _NavTab(icon: Icons.emoji_events_rounded, label: 'Tournaments', path: '/tournaments'),
    _NavTab(icon: Icons.groups_rounded, label: 'Teams', path: '/teams'),
    _NavTab(icon: Icons.person_rounded, label: 'Players', path: '/players'),
  ];

  void _onTap(int index) {
    setState(() => _currentIndex = index);
    context.go(_tabs[index].path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: widget.child,
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        tabs: _tabs,
        onTap: _onTap,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavTab> tabs;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: tabs.asMap().entries.map((e) {
              final isActive = e.key == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primarySurface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            e.value.icon,
                            size: 22,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          e.value.label,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textTertiary,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  final IconData icon;
  final String label;
  final String path;

  const _NavTab({
    required this.icon,
    required this.label,
    required this.path,
  });
}
