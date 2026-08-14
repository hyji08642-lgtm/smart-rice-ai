import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/store/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final session = ref.watch(authSessionController);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('알림', style: theme.textTheme.titleMedium),
          SwitchListTile(
            value: settings.notifications,
            onChanged: notifier.setNotifications,
            title: const Text('알림 받기'),
            subtitle: const Text('AI 추천 · 강우 · ORP/EC 경보'),
          ),
          SwitchListTile(
            value: settings.autoControl,
            onChanged: notifier.setAutoControl,
            title: const Text('AI 자동 제어'),
            subtitle: const Text('신뢰도 0.6 이상만 자동 실행'),
          ),
          const Divider(height: 24),
          Text('표시', style: theme.textTheme.titleMedium),
          ListTile(
            title: const Text('테마'),
            subtitle: Text(
              switch (settings.themeMode) {
                ThemeMode.dark => '다크',
                ThemeMode.light => '라이트',
                ThemeMode.system => '시스템',
              },
            ),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: ThemeMode.dark, child: Text('다크')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('라이트')),
                DropdownMenuItem(value: ThemeMode.system, child: Text('시스템')),
              ],
              onChanged: (v) {
                if (v != null) notifier.setThemeMode(v);
              },
            ),
          ),
          const Divider(height: 24),
          Text('시스템', style: theme.textTheme.titleMedium),
          const ListTile(
            leading: Icon(Icons.smartphone_rounded),
            title: Text('오프라인 상태'),
            subtitle: Text('WiFi 연결됨 · 실시간 동기화'),
          ),
          const ListTile(
            leading: Icon(Icons.memory_rounded),
            title: Text('모델 정보'),
            subtitle: Text('TinyML v2.1 · 신뢰도 임계값 0.6'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('운영일지 내보내기'),
            subtitle: const Text('저탄소 영농 증빙 PDF'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('내보내기 준비 중입니다')),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('로그아웃'),
            subtitle: session == null
                ? null
                : Text('${session.user.username} 계정에서 나가기'),
            onTap: () async {
              await ref.read(authSessionController.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
