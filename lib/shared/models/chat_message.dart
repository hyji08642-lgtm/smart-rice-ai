class ChatMessage {
  const ChatMessage({
    required this.isUser,
    required this.text,
    required this.time,
    this.xaiSteps,
  });

  final bool isUser;
  final String text;
  final DateTime time;
  final List<String>? xaiSteps;
}
