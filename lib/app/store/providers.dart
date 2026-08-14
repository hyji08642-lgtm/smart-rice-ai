import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/risk.dart' show riskLevel, RiskLevel;
import '../../shared/api/account_api.dart';
import '../../shared/api/sensor_api.dart';
import '../../shared/mock/mock_account_api.dart';
import '../../shared/mock/mock_api.dart';
import '../../shared/mock/mock_data.dart';
import '../../shared/models/account.dart';
import '../../shared/models/app_notification.dart';
import '../../shared/models/chat_message.dart';
import '../../shared/models/device.dart';
import '../../shared/models/journal_entry.dart';
import '../../shared/models/paddy.dart';
import '../../shared/models/recommendation.dart';
import '../../shared/models/task_item.dart';
import '../../shared/models/telemetry.dart';
import '../../shared/models/twin_state.dart';
import '../../shared/remote/real_account_api.dart';
import '../../shared/remote/real_api.dart';

/// --dart-define=API_BASE_URL=http://... 지정 시 실제 백엔드(FastAPI)에 연결,
/// 그 외에는 데모용 [MockApi]를 사용한다. 로그인 세션이 있으면 그 토큰으로 인증한다.
final accountApiProvider = Provider<AccountApi>((ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  if (baseUrl.isEmpty) return MockAccountApi() as AccountApi;
  final api = RealAccountApi(baseUrl: baseUrl);
  ref.onDispose(api.dispose);
  return api;
});

/// --dart-define=API_BASE_URL=http://... 지정 시 실제 백엔드(FastAPI)에 연결,
/// 그 외에는 데모용 [MockApi]를 사용한다. 로그인 토큰이 있으면 헤더로 전달한다.
final sensorApiProvider = Provider.autoDispose<SensorApi>((ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  const apiToken = String.fromEnvironment('API_TOKEN');
  final sessionToken = ref.watch(authSessionController.select((s) => s?.token));
  final token = (sessionToken == null || sessionToken.isEmpty)
      ? apiToken
      : sessionToken;
  final api = baseUrl.isEmpty
      ? MockApi() as SensorApi
      : RealApi(baseUrl: baseUrl, apiToken: token) as SensorApi;
  ref.onDispose(api.dispose);
  return api;
});

/// 현재 로그인 세션. null 이면 비로그인 상태다.
///
/// 세션은 기기 로컬([SharedPreferences])에 저장되어 브라우저/기기마다
/// 독립적으로 유지·복원된다. 로그아웃 시 해당 기기의 세션만 삭제된다.
class AuthNotifier extends Notifier<AuthSession?> {
  static const _kToken = 'auth_token';

  @override
  AuthSession? build() => null;

  Future<AuthSession> login(String username, String password) async {
    final session =
        await ref.read(accountApiProvider).login(username, password);
    state = session;
    await _persist(session);
    await _loadAccountData();
    return session;
  }

  Future<AuthSession> signup(String username, String password) async {
    final session =
        await ref.read(accountApiProvider).signup(username, password);
    state = session;
    await _persist(session);
    await _loadAccountData();
    return session;
  }

  Future<void> logout() async {
    await ref.read(accountApiProvider).logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    state = null;
    ref.read(paddiesProvider.notifier).clear();
    ref.read(devicesProvider.notifier).clear();
  }

  /// 앱 시작 시 기기 로컬에 저장된 세션을 복원한다. 없으면 null 유지.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    if (token == null || token.isEmpty) return;
    final api = ref.read(accountApiProvider);
    if (api is RealAccountApi) api.setToken(token);
    try {
      final user = await api.me(token);
      state = AuthSession(token: token, user: user);
      await _loadAccountData();
    } catch (_) {
      // 토큰이 만료/무효하면 로컬 세션을 지우고 비로그인으로 둔다.
      await prefs.remove(_kToken);
    }
  }

  Future<void> _persist(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, session.token);
  }

  Future<void> _loadAccountData() async {
    try {
      final paddies = await ref.read(accountApiProvider).listPaddies();
      ref.read(paddiesProvider.notifier).replaceAll(paddies);
      if (paddies.isNotEmpty) {
        ref.read(selectedPaddyProvider.notifier).select(paddies.first.id);
      }
      final devices = await ref.read(accountApiProvider).listDevices();
      ref.read(devicesProvider.notifier).replaceAll(devices);
    } catch (_) {
      // 계정 데이터 로드 실패는 다음 진입 시 재시도한다.
    }
  }
}

final authSessionController =
    NotifierProvider<AuthNotifier, AuthSession?>(AuthNotifier.new);

final telemetryProvider = StreamProvider.autoDispose<Telemetry>(
  (ref) => ref.watch(sensorApiProvider).telemetry(),
);

final twinProvider = StreamProvider.autoDispose<TwinState>(
  (ref) => ref.watch(sensorApiProvider).twin(),
);

final journalProvider = FutureProvider.autoDispose<List<JournalEntry>>(
  (ref) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return MockData.journal();
  },
);

class PaddiesNotifier extends Notifier<List<Paddy>> {
  @override
  List<Paddy> build() => const [];

  void clear() => state = const [];

  void replaceAll(List<Paddy> paddies) => state = paddies;

  Future<String> addPaddy({
    required String name,
    required String stage,
    required String area,
    List<String> deviceIds = const [],
  }) async {
    final paddy = await ref.read(accountApiProvider).addPaddy(
          name: name,
          stage: stage,
          area: area,
          deviceIds: deviceIds,
        );
    state = [...state, paddy];
    return paddy.id;
  }

  Future<void> removePaddy(String id) async {
    await ref.read(accountApiProvider).removePaddy(id);
    state = state.where((p) => p.id != id).toList();
  }
}

final paddiesProvider = NotifierProvider<PaddiesNotifier, List<Paddy>>(
  PaddiesNotifier.new,
);

class DevicesNotifier extends Notifier<List<Device>> {
  @override
  List<Device> build() => const [];

  void clear() => state = const [];

  void replaceAll(List<Device> devices) => state = devices;

  Future<void> register({
    required String deviceId,
    required String name,
    required String type,
    bool hasGate = false,
    bool hasPump = false,
    List<String> sensors = const [],
  }) async {
    final device = await ref.read(accountApiProvider).registerDevice(
          deviceId: deviceId,
          name: name,
          type: type,
          hasGate: hasGate,
          hasPump: hasPump,
          sensors: sensors,
        );
    state = [...state, device];
  }

  Future<void> remove(String deviceId) async {
    await ref.read(accountApiProvider).removeDevice(deviceId);
    state = state.where((d) => d.deviceId != deviceId).toList();
  }

  Future<void> attachToPaddy(String paddyId, List<String> deviceIds) async {
    await ref.read(accountApiProvider).setPaddyDevices(paddyId, deviceIds);
  }
}

final devicesProvider = NotifierProvider<DevicesNotifier, List<Device>>(
  DevicesNotifier.new,
);

class SelectedPaddyNotifier extends Notifier<String> {
  @override
  String build() => 'paddy_a';

  void select(String id) {
    if (state == id) return;
    state = id;
    ref.read(sensorApiProvider).select(id);
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
  (ref) => ref.watch(sensorApiProvider).notifications(),
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
