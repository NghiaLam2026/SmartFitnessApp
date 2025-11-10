class SchedulerEvent {
  final String id;
  final DateTime date;
  final String title;
  final String? note;

  SchedulerEvent({
    required this.id,
    required this.date,
    required this.title,
    this.note,
  });
}
