enum JournalEventType { decision, execution, expected, actual, notice }

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.time,
    required this.title,
    required this.type,
    this.detail,
  });

  final String id;
  final DateTime time;
  final String title;
  final JournalEventType type;
  final String? detail;
}
