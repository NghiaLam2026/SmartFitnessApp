import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

/// Whether the mood was logged before or after a meditation session.
enum MoodSessionType { before, after, checkin }

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

/// Supabase-backed repository for moods. Maintains an in-memory cache
/// so the calendar view can read synchronously while data stays persisted.
class MoodRepository {
  MoodRepository._();

  static final MoodRepository instance = MoodRepository._();

  final SupabaseClient _client = supabase;
  final Map<DateTime, MoodEntry> _entries = {};

  DateTime _key(DateTime d) => DateTime(d.year, d.month, d.day);

  MoodEntry? getEntryForDay(DateTime day) => _entries[_key(day)];

  Map<DateTime, MoodEntry> getAllMoods() => Map.unmodifiable(_entries);

  Future<void> loadRecent({int days = 60}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      _entries.clear();
      return;
    }

    final from = DateTime.now().toUtc().subtract(Duration(days: days));
    final rows = await _client
        .from('meditation_sessions')
        .select('started_at, before_mood, after_mood')
        .eq('user_id', userId)
        .gte('started_at', from.toIso8601String())
        .order('started_at', ascending: false);

    _entries.clear();
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      _applySessionRow(row);
    }
  }

  void applyMood({
    required DateTime timestamp,
    required MoodSessionType type,
    required String moodLabel,
  }) {
    final key = _key(timestamp);
    final existing = _entries[key] ?? const MoodEntry();

    switch (type) {
      case MoodSessionType.before:
        _entries[key] = existing.copyWith(beforeMood: moodLabel);
        break;
      case MoodSessionType.after:
        _entries[key] = existing.copyWith(afterMood: moodLabel);
        break;
      case MoodSessionType.checkin:
        _entries[key] = existing.copyWith(beforeMood: moodLabel);
        break;
    }
  }

  void _applySessionRow(Map<String, dynamic> row) {
    final startedAtRaw = row['started_at'] as String?;
    if (startedAtRaw == null) return;

    final startedAt = DateTime.parse(startedAtRaw).toLocal();
    final before = row['before_mood'] as String?;
    final after = row['after_mood'] as String?;

    if (before != null && before.isNotEmpty) {
      applyMood(
        timestamp: startedAt,
        type: MoodSessionType.before,
        moodLabel: before,
      );
    }

    if (after != null && after.isNotEmpty) {
      applyMood(
        timestamp: startedAt,
        type: MoodSessionType.after,
        moodLabel: after,
      );
    }
  }
}
