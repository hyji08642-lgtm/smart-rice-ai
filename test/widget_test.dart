import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_rice_ai/app/core/utils/risk.dart';
import 'package:smart_rice_ai/app/core/widgets/app_card.dart';
import 'package:smart_rice_ai/app/store/providers.dart';
import 'package:smart_rice_ai/app/theme/app_theme.dart';
import 'package:smart_rice_ai/features/control/control_screen.dart';
import 'package:smart_rice_ai/features/farms/farms_screen.dart';
import 'package:smart_rice_ai/features/auth/login_screen.dart';
import 'package:smart_rice_ai/features/home/home_screen.dart';
import 'package:smart_rice_ai/features/notification/notification_screen.dart';
import 'package:smart_rice_ai/features/paddy/paddy_screen.dart';
import 'package:smart_rice_ai/main.dart';
import 'package:smart_rice_ai/shared/mock/mock_data.dart';
import 'package:smart_rice_ai/shared/models/app_notification.dart';
import 'package:smart_rice_ai/shared/models/paddy.dart';
import 'package:smart_rice_ai/shared/models/telemetry.dart';
import 'package:smart_rice_ai/shared/models/twin_state.dart';

const _telemetry = Telemetry(
  paddyId: 'paddy_a',
  orp: 310.2,
  ec: 1.28,
  waterLevel: 5.8,
  soilMoisture: 40.2,
  waterTemp: 26.0,
  batterySoc: 78.5,
  solarV: 18.2,
  gateOpen: true,
  pumpOn: true,
  rssi: -62,
  methaneScore: 0.78,
  orpDelta1h: -10.3,
  rain3h: false,
);

const _twin = TwinState(
  paddyId: 'paddy_a',
  waterLevel: 5.8,
  predictedLevel3h: 4.0,
  orp: 310.2,
  predictedOrp3h: 325.0,
  methaneScore: 0.78,
  gateOpen: true,
  pumpOn: true,
  weather: 'sunny',
  tempC: 28.0,
  rain3h: false,
  awdPhase: 'flooded',
);

Widget _home(Telemetry t) => ProviderScope(
      overrides: [
        paddiesProvider.overrideWith(
          () => _SeededPaddiesNotifier(MockData.paddies()),
        ),
        telemetryProvider.overrideWith((ref) => Stream.value(t)),
        journalProvider.overrideWith((ref) async => MockData.journal()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const HomeScreen(),
      ),
    );

GoRouter _farmsRouter() => GoRouter(
      initialLocation: '/farms',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('HOME'))),
        ),
        GoRoute(
          path: '/paddy',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('PADDY'))),
        ),
        GoRoute(
          path: '/devices',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('DEVICES'))),
        ),
        GoRoute(
          path: '/farms',
          builder: (_, _) => const FarmsScreen(),
        ),
      ],
    );

/// 데모 계정(demo/demo1234)으로 로그인해 논/기기 시드를 로드한다.
/// 화면을 아직 띄우지 않은 상태(라우터 미장착)에서 provider 만 준비해 두고,
/// 이후 테스트에서 [tester.pumpWidget] 로 화면을 올린다.
class _SeededPaddiesNotifier extends PaddiesNotifier {
  _SeededPaddiesNotifier(this.seed);

  final List<Paddy> seed;

  @override
  List<Paddy> build() => seed;
}

Future<ProviderContainer> _authedContainer(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final login = container.read(authSessionController.notifier).login('demo', 'demo1234');
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await login;
  return container;
}

void main() {
  group('risk helpers', () {
    test('maps score to label', () {
      expect(riskLabel(0.2), '안전');
      expect(riskLabel(0.5), '주의');
      expect(riskLabel(0.7), '위험');
      expect(riskLabel(0.9), '심각');
    });
  });

  group('api json contract', () {
    test('telemetry parses backend json', () {
      final t = Telemetry.fromJson(const {
        'paddy_id': 'paddy_a',
        'orp': 310.2,
        'ec': 1.28,
        'water_level': 5.8,
        'soil_moisture': 40.2,
        'water_temp': 26.0,
        'battery_soc': 78.5,
        'solar_v': 18.2,
        'gate_open': false,
        'pump_on': false,
        'rssi': -62,
        'methane_score': 0.78,
        'orp_delta_1h': -10.3,
        'rain_3h': false,
      });
      expect(t.paddyId, 'paddy_a');
      expect(t.orp, 310.2);
      expect(t.waterLevel, 5.8);
      expect(t.gateOpen, isFalse);
      expect(t.pumpOn, isFalse);
      expect(t.methaneScore, 0.78);
    });

    test('twin parses awd phase from backend json', () {
      final twin = TwinState.fromJson(const {
        'paddy_id': 'paddy_a',
        'water_level': 5.8,
        'predicted_level_3h': 4.0,
        'orp': 310.2,
        'predicted_orp_3h': 325.0,
        'methane_score': 0.78,
        'gate_open': true,
        'pump_on': false,
        'weather': 'sunny',
        'temp_c': 28.0,
        'rain_3h': false,
        'awd_phase': 'draining',
      });
      expect(twin.awdPhase, 'draining');
      expect(twin.predictedLevel3h, 4.0);
    });

    test('notification parses type by name', () {
      final n = AppNotification.fromJson(const {
        'id': 'paddy_a_1_awdDrain',
        'time': '2026-08-12T07:17:49+00:00',
        'type': 'awdDrain',
        'title': '논 A · AWD 배수 시작',
        'body': '배수 시작',
        'read': true,
      });
      expect(n.type, NotificationType.awdDrain);
      expect(n.read, isTrue);
      expect(n.time.year, 2026);
    });
  });

  testWidgets('home renders action-first sections', (tester) async {
    await tester.pumpWidget(_home(_telemetry));
    await tester.pump();

    expect(find.text('Smart Rice AI'), findsOneWidget);
    expect(find.text('논 A'), findsWidgets);
    expect(find.text('AI 비서'), findsOneWidget);
    expect(find.text('메탄 위험도 위험'), findsOneWidget);
    expect(find.text('오늘 해야 할 일'), findsOneWidget);
    expect(find.text('AI 추천 배수 확인하기'), findsOneWidget);
    expect(find.text('지금 하기'), findsOneWidget);
    expect(find.text('내 논 상태'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('바로가기'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('바로가기'), findsOneWidget);
    expect(find.text('원격 제어'), findsOneWidget);
    expect(find.text('AI 상담'), findsOneWidget);
  });

  testWidgets('task check toggles complete state', (tester) async {
    await tester.pumpWidget(_home(_telemetry));
    await tester.pump();

    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    await tester.tap(find.byIcon(Icons.radio_button_unchecked));
    await tester.pump();

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
  });

  testWidgets('control screen applies AI recommendation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          telemetryProvider.overrideWith((ref) => Stream.value(_telemetry)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const ControlScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('현재 상태'), findsOneWidget);
    expect(find.text('AI 자동 제어'), findsOneWidget);
    expect(find.text('AI 추천 대기 중'), findsOneWidget);

    await tester.tap(find.text('AI 추천 적용하기'));
    await tester.pump();

    expect(find.text('AI 추천을 적용했습니다. AWD 배수를 시작합니다.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('login screen signs in and reaches home', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/login',
            routes: [
              GoRoute(
                path: '/login',
                builder: (_, _) => const LoginScreen(),
              ),
              GoRoute(
                path: '/home',
                builder: (_, _) =>
                    const Scaffold(body: Center(child: Text('HOME'))),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('로그인'), findsWidgets);

    await tester.enterText(
        find.widgetWithText(TextField, '아이디'), 'demo');
    await tester.enterText(
        find.widgetWithText(TextField, '비밀번호'), 'demo1234');
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('app boots from splash to login when signed out', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SmartRiceAiApp()));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('로그인'), findsWidgets);
    expect(find.text('처음이에요 → 회원가입'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('control buttons locked under AI auto control', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const ControlScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    ButtonStyleButton button(String label) =>
        tester.widget<ButtonStyleButton>(
          find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate(
              (w) => w is FilledButton || w is OutlinedButton,
            ),
          ),
        );

    expect(find.text('AI 제어 중'), findsOneWidget);
    expect(button('펌프 켜기').onPressed, isNull);
    expect(button('펌프 끄기').onPressed, isNull);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(find.text('AI 제어 중'), findsNothing);
    expect(button('펌프 켜기').onPressed, isNotNull);
    expect(button('펌프 끄기').onPressed, isNotNull);

    await tester.tap(find.text('펌프 켜기'));
    await tester.pump();

    final pumpOnButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('펌프 켜기'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(pumpOnButton.onPressed, isNotNull);
    expect(
      find.ancestor(
        of: find.text('펌프 끄기'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('farms adds paddy and navigates home', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = await _authedContainer(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: _farmsRouter()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('논 A'), findsOneWidget);
    expect(find.text('새 논 추가'), findsOneWidget);

    await tester.tap(find.text('새 논 추가'));
    await tester.pumpAndSettle();

    expect(find.text('생육 단계'), findsOneWidget);
    expect(find.text('면적'), findsOneWidget);

    await tester.tap(find.text('추가하기'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('farms deletes paddy', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = await _authedContainer(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: _farmsRouter()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('논 C'), findsOneWidget);

    final deleteIcon = find.descendant(
      of: find.widgetWithText(AppCard, '논 C'),
      matching: find.byIcon(Icons.delete_outline_rounded),
    );
    await tester.tap(deleteIcon);
    await tester.pumpAndSettle();

    expect(find.text('논 삭제'), findsOneWidget);
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.text('논 C'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('farms paddy tap navigates to paddy view', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = await _authedContainer(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: _farmsRouter()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('논 B'));
    await tester.pumpAndSettle();

    expect(find.text('PADDY'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('notification screen shows only AWD related alerts', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const NotificationScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('알림'), findsWidgets);
    expect(find.textContaining('논 A · AWD'), findsWidgets);
    expect(find.textContaining('논 A · 메탄 위험'), findsOneWidget);
    expect(find.text('강우 예보'), findsNothing);
    expect(find.text('EC 이상'), findsNothing);
    expect(find.text('배터리 부족'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('paddy view shows identity, sensors and twin', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        telemetryProvider.overrideWith((ref) => Stream.value(_telemetry)),
        twinProvider.overrideWith((ref) => Stream.value(_twin)),
      ],
    );
    addTearDown(container.dispose);
    final login =
        container.read(authSessionController.notifier).login('demo', 'demo1234');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await login;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const PaddyScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('논 A'), findsWidgets);
    expect(find.text('간단관개기 · 1,200㎡'), findsOneWidget);
    expect(find.text('Digital Twin · 실시간'), findsOneWidget);
    expect(find.text('28°C 맑음'), findsOneWidget);
    expect(find.text('AWD 담수'), findsWidgets);
    expect(find.text('AWD 사이클 · 담수'), findsOneWidget);
    expect(find.text('센서 상태'), findsOneWidget);
    expect(find.text('토양수분'), findsWidgets);
    expect(find.text('EC'), findsWidgets);
    expect(find.text('신호'), findsWidgets);
    expect(find.textContaining('연결된 세트 ('), findsOneWidget);
    expect(find.text('논 A 1구역 세트'), findsOneWidget);
    expect(find.text('논 A 2구역 세트'), findsOneWidget);
    expect(find.text('AI 예측 · 3시간 후'), findsOneWidget);
    expect(find.text('수문 열림'), findsOneWidget);
    expect(find.text('펌프 가동'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
