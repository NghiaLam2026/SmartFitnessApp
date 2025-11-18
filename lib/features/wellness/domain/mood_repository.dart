import 'package:flutter/foundation.dart';

/// Whether the mood was logged before or after a meditation session.
enum MoodSessionType { before, after }

/// Stores mood for a single day.
class MoodEntry {
  final String? beforeMood;
  final String? afterMood;

  const MoodEntry({this.beforeMood, this.afterMood});

  MoodEntry copyWith({
    String? beforeMood,
    String? afterMood,
  }) {
    return MoodEntry(
      beforeMood: beforeMood ?? this.beforeMood,
      afterMood: afterMood ?? this.afterMood,
    );
  }
}

/// Very simple in-memory repository for moods.
/// (If needed later, you can back this with Supabase.)
class MoodRepository {
  MoodRepository._();

  static final MoodRepository instance = MoodRepository._();

  final Map<DateTime, MoodEntry> _entries = {};

  DateTime _key(DateTime d) => DateTime(d.year, d.month, d.day);

  MoodEntry? getEntryForDay(DateTime day) {
    return _entries[_key(day)];
  }

  void setMood(DateTime day, MoodSessionType type, String moodLabel) {
    final key = _key(day);
    final existing = _entries[key] ?? const MoodEntry();

    switch (type) {
      case MoodSessionType.before:
        _entries[key] = existing.copyWith(beforeMood: moodLabel);
        break;
      case MoodSessionType.after:
        _entries[key] = existing.copyWith(afterMood: moodLabel);
        break;
    }
  }

  /// Optional: read-only snapshot of all moods.
  Map<DateTime, MoodEntry> getAllMoods() => Map.unmodifiable(_entries);
}
