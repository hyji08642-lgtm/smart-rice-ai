import '../models/app_notification.dart';
import '../models/chat_message.dart';
import '../models/journal_entry.dart';
import '../models/paddy.dart';
import '../models/recommendation.dart';
import '../models/task_item.dart';
import '../models/telemetry.dart';

class MockData {
  MockData._();

  static List<Paddy> paddies() => const [
        Paddy(
          id: 'paddy_a',
          name: '논 A',
          stage: '간단관개기',
          area: '1,200㎡',
          riskScore: 0.78,
        ),
        Paddy(
          id: 'paddy_b',
          name: '논 B',
          stage: '담수기',
          area: '850㎡',
          riskScore: 0.22,
        ),
        Paddy(
          id: 'paddy_c',
          name: '논 C',
          stage: '중간낙수기',
          area: '1,500㎡',
          riskScore: 0.62,
        ),
      ];

  static List<TaskItem> todayTasks(Telemetry? t) {
    final tasks = <TaskItem>[
      const TaskItem(id: 't_check', text: '논 상태 한 번 확인하기', kind: TaskKind.check),
    ];
    if (t == null) return tasks;
    if (t.methaneScore >= 0.6) {
      tasks.add(
        const TaskItem(
          id: 't_drain',
          text: 'AI 추천 배수 확인하기',
          kind: TaskKind.action,
          action: '지금 하기',
        ),
      );
    }
    if (t.rain3h) {
      tasks.add(
        const TaskItem(id: 't_rain', text: '강우 대비 수문 정리', kind: TaskKind.alert),
      );
    }
    if (t.batterySoc < 30) {
      tasks.add(
        const TaskItem(id: 't_battery', text: '배터리 충전 확인', kind: TaskKind.alert),
      );
    }
    return tasks;
  }

  static Recommendation recommendation() => const Recommendation(
        id: 'd_0042',
        title: 'AWD 배수 시작',
        action: 'drain',
        confidence: 0.87,
        reason:
            'ORP가 24h 내 -10.3mV 감소해 메탄 위험이 높아졌습니다. 간단관개 배수로 회복을 권장합니다.',
        xaiSteps: [
          'ORP 감소 (-10.3mV) → 혐기 상태 진입',
          '메탄 발생 위험 증가 (0.78)',
          'AWD 간단관개 배수 필요',
          '배수 후 12h 내 ORP +15mV 회복 예상',
        ],
      );

  static List<JournalEntry> journal() {
    final now = DateTime.now();
    return [
      JournalEntry(
        id: 'j1',
        time: now.subtract(const Duration(minutes: 30)),
        title: '배수 결정 (AWD)',
        type: JournalEventType.decision,
        detail: 'ORP -10.3mV · 메탄 위험 증가',
      ),
      JournalEntry(
        id: 'j2',
        time: now.subtract(const Duration(minutes: 25)),
        title: '수문 OPEN · 펌프 ON',
        type: JournalEventType.execution,
        detail: '신뢰도 0.87 · 사용자 승인',
      ),
      JournalEntry(
        id: 'j3',
        time: now.subtract(const Duration(minutes: 20)),
        title: '예상: 12h 내 ORP +15mV 회복',
        type: JournalEventType.expected,
      ),
      JournalEntry(
        id: 'j4',
        time: now.subtract(const Duration(minutes: 5)),
        title: 'ORP 325.0 (+14.8) 회복 진행',
        type: JournalEventType.actual,
        detail: '예상대로 회복 중',
      ),
      JournalEntry(
        id: 'j5',
        time: now.subtract(const Duration(days: 1, hours: 3)),
        title: '강우 예보 수신',
        type: JournalEventType.notice,
        detail: '3h 내 강우 80%',
      ),
    ];
  }

  static List<AppNotification> notifications() {
    final now = DateTime.now();
    return [
      AppNotification(
        id: 'n1',
        time: now.subtract(const Duration(minutes: 12)),
        type: NotificationType.rain,
        title: '강우 예보',
        body: '3시간 후 비가 와요. 배수 준비를 마쳤어요.',
        read: true,
      ),
      AppNotification(
        id: 'n2',
        time: now.subtract(const Duration(hours: 1)),
        type: NotificationType.methaneRisk,
        title: '메탄 위험',
        body: '논 A의 메탄 위험이 높아졌어요. 배수를 권장해요.',
      ),
      AppNotification(
        id: 'n3',
        time: now.subtract(const Duration(hours: 2)),
        type: NotificationType.ecRisk,
        title: 'EC 이상',
        body: 'EC가 올라가고 있어요. 비료 사용량을 확인해 주세요.',
      ),
      AppNotification(
        id: 'n4',
        time: now.subtract(const Duration(hours: 3)),
        type: NotificationType.battery,
        title: '배터리 부족',
        body: '배터리가 28%예요. 충전을 확인해 주세요.',
      ),
    ];
  }

  static List<ChatMessage> chat() {
    final now = DateTime.now();
    return [
      ChatMessage(
        isUser: false,
        text: '안녕하세요! 논 A 상태를 알려드릴게요. 지금 물어보고 싶은 게 있으면 편하게 말씀하세요.',
        time: now.subtract(const Duration(minutes: 10)),
      ),
      ChatMessage(
        isUser: true,
        text: '오늘 상태는 어때?',
        time: now.subtract(const Duration(minutes: 9)),
      ),
      ChatMessage(
        isUser: false,
        text:
            '오늘은 메탄 위험이 좀 있어요. 오전에 물을 살짝 빼 주면 비가 오기 전에 마칠 수 있어요. 물은 5.8cm로 적당해요.',
        time: now.subtract(const Duration(minutes: 9)),
      ),
      ChatMessage(
        isUser: false,
        text:
            '왜 배수해야 하는지 궁금하면 말씀해 주세요. 원격 제어에서 바로 실행할 수도 있어요.',
        time: now.subtract(const Duration(minutes: 8)),
      ),
    ];
  }
}
