enum TaskKind { check, action, alert }

class TaskItem {
  const TaskItem({
    required this.id,
    required this.text,
    required this.kind,
    this.action,
    this.done = false,
  });

  final String id;
  final String text;
  final TaskKind kind;
  final String? action;
  final bool done;
}
