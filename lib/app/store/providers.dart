import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/risk.dart' show riskLevel, RiskLevel;
import '../../shared/mock/mock_api.dart';
import '../../shared/mock/mock_data.dart';
import '../../shared/models/app_notification.dart';
import '../../shared/models/chat_message.dart';
import '../../shared/models/journal_entry.dart';
import '../../shared/models/paddy.dart';
import '../../shared/models/recommendation.dart';
import '../../shared/models/task_item.dart';
import '../../shared/models/telemetry.dart';
import '../../shared/models/twin_state.dart';

final mockApiProvider = Provider.autoDispose<MockApi>((ref) {
  final api = MockApi();
  ref.onDispose(api.dispose);
  return api;
});

final telemetryProvider = StreamProvider.autoDispose<Telemetry>(
  (ref) => ref.watch(mockApiProvider).telemetry(),
);

final twinProvider = StreamProvider.autoDispose<TwinState>(
  (ref) => ref.watch(mockApiProvider).twin(),
);

final journalProvider = FutureProvider.autoDispose<List<JournalEntry>>(
  (ref) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return MockData.journal();
  },
);

class PaddiesNotifier extends Notifier<List<Paddy>> {
  @override
  List<Paddy> build() => MockData.paddies();

  String addPaddy({
    required String name,
    required String stage,
    required String area,
  }) {
    final id = 'paddy_${state.length + 1}';
    state = [
      ...state,
      Paddy(id: id, name: name, stage: stage, area: area, riskScore: 0.3),
    ];
    return id;
  }

  void removePaddy(String id) {
    state = state.where((p) => p.id != id).toList();
  }
}

final paddiesProvider = NotifierProvider<PaddiesNotifier, List<Paddy>>(
  PaddiesNotifier.new,
);

class SelectedPaddyNotifier extends Notifier<String> {
  @override
  String build() => 'paddy_a';

  void select(String id) {
    if (state == id) return;
    state = id;
    ref.read(mockApiProvider).select(id);
  }
}

final selectedPaddyProvider =
    NotifierProvider<SelectedPaddyNotifier, String>(SelectedPaddyNotifier.new);

final aiSummaryProvider = Provider<String>((ref) {
  final t = ref.watch(telemetryProvider).value;
  if (t == null) return '논 상태를 확인하는 중이에요.';
  return switch (riskLevel(t.methaneScore)) {
    RiskLevel.severe =>
      '메탄 위험이 매우 높아요. 지금 바로 배수하고 원격 제어에서 실행해 주세요.',
    RiskLevel.high =>
      '메탄 위험이 높아지고 있어요. 오전에 AWD 배수를 시작하면 12시간 안에 회복할 수 있어요.',
    RiskLevel.caution => '조금만 신경 쓰면 돼요. 물을 살짝 빼 두면 더 안전해요.',
    RiskLevel.safe => t.rain3h
        ? '비가 오기 전에 수문을 점검하세요. 물이 넘치지 않게 준비해요.'
        : '오늘은 별일 없어요. 물이 잘 유지되고 있어요.',
  };
});

class TodayTasksNotifier extends Notifier<List<TaskItem>> {
  @override
  List<TaskItem> build() =>
      MockData.todayTasks(ref.watch(telemetryProvider).value);

  void toggle(String id) {
    state = [
      for (final t in state)
        t.id == id
            ? TaskItem(id: t.id, text: t.text, kind: t.kind, action: t.action, done: !t.done)
            : t,
    ];
  }
}

final todayTasksProvider =
    NotifierProvider<TodayTasksNotifier, List<TaskItem>>(TodayTasksNotifier.new);

class RecommendationNotifier extends Notifier<Recommendation> {
  @override
  Recommendation build() => MockData.recommendation();

  Recommendation _copy(RecommendationStatus status) => Recommendation(
        id: state.id,
        title: state.title,
        action: state.action,
        confidence: state.confidence,
        reason: state.reason,
        xaiSteps: state.xaiSteps,
        status: status,
      );

  void approve() => state = _copy(RecommendationStatus.approved);

  void reject() => state = _copy(RecommendationStatus.rejected);
}

final recommendationProvider =
    NotifierProvider<RecommendationNotifier, Recommendation>(
  RecommendationNotifier.new,
);

final notificationsProvider = StreamProvider.autoDispose<List<AppNotification>>(
  (ref) => ref.watch(mockApiProvider).notifications(),
);

class ChatNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => MockData.chat();

  void send(String text) {
    state = [
      ...state,
      ChatMessage(isUser: true, text: text, time: DateTime.now()),
    ];
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (state.isEmpty) return;
      state = [
        ...state,
        ChatMessage(
          isUser: false,
          text:
              '알겠어요. 지금 상태로는 오전에 배수하고, 비 오기 전에 마치는 게 좋아요. 원격 제어 탭에서 바로 실행해 볼 수 있어요.',
          time: DateTime.now(),
        ),
      ];
    });
  }
}

final chatProvider = NotifierProvider<ChatNotifier, List<ChatMessage>>(
  ChatNotifier.new,
);

class Settings {
  const Settings({
    required this.autoControl,
    required this.notifications,
    required this.themeMode,
  });

  final bool autoControl;
  final bool notifications;
  final ThemeMode themeMode;

  Settings copyWith({bool? autoControl, bool? notifications, ThemeMode? themeMode}) =>
      Settings(
        autoControl: autoControl ?? this.autoControl,
        notifications: notifications ?? this.notifications,
        themeMode: themeMode ?? this.themeMode,
      );
}

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() =>
      const Settings(autoControl: true, notifications: true, themeMode: ThemeMode.system);

  void setAutoControl(bool v) => state = state.copyWith(autoControl: v);

  void setNotifications(bool v) => state = state.copyWith(notifications: v);

  void setThemeMode(ThemeMode v) => state = state.copyWith(themeMode: v);
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);
