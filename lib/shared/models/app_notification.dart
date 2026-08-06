enum NotificationType { rain, methaneRisk, ecRisk, battery }

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
}
