import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (icon: Icons.home_rounded, label: '홈'),
    (icon: Icons.agriculture_rounded, label: '내 농장'),
    (icon: Icons.tune_rounded, label: '원격 제어'),
    (icon: Icons.history_rounded, label: '일지'),
    (icon: Icons.notifications_rounded, label: '알림'),
  ];

  void _go(int index) =>
      navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;
    return LayoutBuilder(
      builder: (context, constraints) {
        final destinations = [
          for (final t in _tabs)
            NavigationDestination(icon: Icon(t.icon), label: t.label),
        ];

        if (constraints.maxWidth >= 840) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: _go,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final t in _tabs)
                      NavigationRailDestination(
                        icon: Icon(t.icon),
                        label: Text(t.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }

        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: _go,
            destinations: destinations,
          ),
          floatingActionButton: index == 0 ? const _ChatFab() : null,
        );
      },
    );
  }
}

class _ChatFab extends StatelessWidget {
  const _ChatFab();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => context.push('/chat'),
      tooltip: 'AI 상담',
      child: const Icon(Icons.chat_rounded),
    );
  }
}
