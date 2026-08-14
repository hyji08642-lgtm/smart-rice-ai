import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/control/control_screen.dart';
import '../../features/devices/devices_screen.dart';
import '../../features/farms/farms_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/journal/journal_screen.dart';
import '../../features/notification/notification_screen.dart';
import '../../features/paddy/paddy_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../core/widgets/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/farms',
              builder: (context, state) => const FarmsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/control',
              builder: (context, state) => const ControlScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/journal',
              builder: (context, state) => const JournalScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/notifications',
              builder: (context, state) => const NotificationScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/paddy',
      builder: (context, state) => const PaddyScreen(),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/devices',
      builder: (context, state) => const DevicesScreen(),
    ),
  ],
);
