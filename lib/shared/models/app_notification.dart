enum NotificationType { methaneRisk, awdDrain, awdDry, awdReflood, awdFlood }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.time,
    required this.type,
    required this.title,
    required this.body,
    this.read = false,
  });

  final String id;
  final DateTime time;
  final NotificationType type;
  final String title;
  final String body;
  final bool read;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        time: DateTime.parse(json['time'] as String),
        type: NotificationType.values.byName(json['type'] as String),
        title: json['title'] as String,
        body: json['body'] as String,
        read: json['read'] as bool? ?? false,
      );
}
