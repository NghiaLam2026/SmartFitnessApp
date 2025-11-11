class SchedulerEvent {
  final String id;
  final DateTime date;
  final String title;
  final String? note;
  final String? workoutId; // Optional link to a workout plan
  final String? workoutTitle; // Denormalized workout title for display

  SchedulerEvent({
    required this.id,
    required this.date,
    required this.title,
    this.note,
    this.workoutId,
    this.workoutTitle,
  });

  /// Create a SchedulerEvent from a database map
  factory SchedulerEvent.fromMap(Map<String, dynamic> map) {
    // Parse date - handle both DATE string (YYYY-MM-DD) and TIMESTAMP
    DateTime date;
    final dateValue = map['date'];
    if (dateValue is String) {
      // Handle DATE format (YYYY-MM-DD) or ISO8601 timestamp
      if (dateValue.contains('T')) {
        date = DateTime.parse(dateValue);
      } else {
        date = DateTime.parse('${dateValue}T00:00:00Z');
      }
    } else if (dateValue is DateTime) {
      date = dateValue;
    } else {
      throw FormatException('Invalid date format: $dateValue');
    }

    // Normalize to day-only (remove time component)
    date = DateTime(date.year, date.month, date.day);

    return SchedulerEvent(
      id: map['id'] as String,
      date: date,
      title: map['title'] as String,
      note: map['note'] as String?,
      workoutId: map['workout_id'] as String?,
      workoutTitle: map['workout_title'] as String?, // May come from join query
    );
  }

  /// Convert SchedulerEvent to a map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String().split('T')[0], // Format as YYYY-MM-DD
      'title': title,
      'note': note,
      'workout_id': workoutId,
    };
  }

  /// Create a copy of this event with optional field updates
  SchedulerEvent copyWith({
    String? id,
    DateTime? date,
    String? title,
    String? note,
    String? workoutId,
    String? workoutTitle,
  }) {
    return SchedulerEvent(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      note: note ?? this.note,
      workoutId: workoutId ?? this.workoutId,
      workoutTitle: workoutTitle ?? this.workoutTitle,
    );
  }
}
