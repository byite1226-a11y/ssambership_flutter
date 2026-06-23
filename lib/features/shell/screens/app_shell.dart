import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive.dart';

/// 하나의 네비게이션 목적지.
class ShellDest {
  const ShellDest({required this.icon, required this.selectedIcon, required this.label});
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// 반응형 앱 셸.
///
/// ★ 태블릿 UX 핵심 (Task 4): 폭이 넓으면 하단 탭 대신 **측면 NavigationRail**을
/// 써서 큰 화면을 세로로 낭비하지 않고, 한 손/양손 어디서든 닿기 쉽게 합니다.
/// 폰에서는 익숙한 하단 NavigationBar로 떨어집니다. go_router의
/// StatefulNavigationShell을 그대로 받아 각 탭의 상태(스크롤/스택)를 보존합니다.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.destinations,
  });

  final StatefulNavigationShell navigationShell;
  final List<ShellDest> destinations;

  void _go(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.useWideLayout;
    if (wide) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.primarySoft,
              destinations: destinations
                  .map((d) => NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon:
                            Icon(d.selectedIcon, color: AppColors.primary),
                        label: Text(d.label),
                      ))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _go,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySoft,
        destinations: destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon, color: AppColors.primary),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }
}
