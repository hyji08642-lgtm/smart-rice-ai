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
import 'package:smart_rice_ai/features/home/home_screen.dart';
import 'package:smart_rice_ai/main.dart';
import 'package:smart_rice_ai/shared/mock/mock_data.dart';
import 'package:smart_rice_ai/shared/models/telemetry.dart';

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

Widget _home(Telemetry t) => ProviderScope(
      overrides: [
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
          path: '/farms',
          builder: (_, _) => const FarmsScreen(),
        ),
      ],
    );

void main() {
  group('risk helpers', () {
    test('maps score to label', () {
      expect(riskLabel(0.2), '안전');
      expect(riskLabel(0.5), '주의');
      expect(riskLabel(0.7), '위험');
      expect(riskLabel(0.9), '심각');
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

  testWidgets('app boots from splash to home', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SmartRiceAiApp()));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Smart Rice AI'), findsWidgets);
    expect(find.text('AI 비서'), findsOneWidget);
    expect(find.text('오늘 해야 할 일'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('control buttons reflect manual state', (tester) async {
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

    Finder filledWith(String label) => find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        );

    expect(filledWith('펌프 켜기'), findsOneWidget);
    expect(filledWith('펌프 끄기'), findsNothing);

    await tester.tap(find.text('펌프 끄기'));
    await tester.pump();

    expect(filledWith('펌프 끄기'), findsOneWidget);
    expect(filledWith('펌프 켜기'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('farms adds paddy and navigates home', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: _farmsRouter())),
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
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: _farmsRouter())),
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
}
