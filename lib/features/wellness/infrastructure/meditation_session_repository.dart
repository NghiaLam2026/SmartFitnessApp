import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/mood_repository.dart';
import '../presentation/meditation_page.dart';

class MeditationSession {
  const MeditationSession({
    required this.id,
    required this.meditationId,
    required this.startedAt,
    this.completedAt,
    this.duration,
    this.beforeMood,
    this.afterMood,
    this.meditationName,
  });

  final String id;
  final String meditationId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final Duration? duration;
  final String? beforeMood;
  final String? afterMood;
  final String? meditationName;

  factory MeditationSession.fromMap(Map<String, dynamic> map) {
    final startedAt = map['started_at'] as String?;
    final completedAt = map['completed_at'] as String?;
    final durationSec = map['duration_sec'] as int?;

    return MeditationSession(
      id: (map['id'] as String?) ?? '',
      meditationId: (map['meditation_id'] as String?) ?? '',
      startedAt: startedAt != null ? DateTime.parse(startedAt).toLocal() : DateTime.now(),
      completedAt:
          completedAt != null ? DateTime.parse(completedAt).toLocal() : null,
      duration: durationSec != null ? Duration(seconds: durationSec) : null,
      beforeMood: map['before_mood'] as String?,
      afterMood: map['after_mood'] as String?,
      meditationName: map['meditation_name'] as String?,
    );
  }
}

class MeditationSessionRepository {
  MeditationSessionRepository({SupabaseClient? client})
      : _client = client ?? supabase;

  final SupabaseClient _client;

  Future<MeditationSession> startSession({
    required MeditationRoutine routine,
    String? beforeMood,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('User must be authenticated to start a session.');
    }

    final response = await _client
        .from('meditation_sessions')
        .insert({
          'user_id': userId,
          'meditation_id': routine.id,
          if (beforeMood != null) 'before_mood': beforeMood,
        })
        .select('id, meditation_id, started_at, before_mood')
        .single();

    return MeditationSession.fromMap(response);
  }

  Future<MeditationSession> completeSession({
    required String sessionId,
    required Duration duration,
    String? afterMood,
    String? meditationName,
  }) async {
    final completedAt = DateTime.now().toUtc().toIso8601String();

    final response = await _client
        .from('meditation_sessions')
        .update({
          'completed_at': completedAt,
          'duration_sec': duration.inSeconds,
          if (afterMood != null) 'after_mood': afterMood,
          if (meditationName != null) 'meditation_name': meditationName,
        })
        .eq('id', sessionId)
        .select(
            'id, meditation_id, started_at, completed_at, duration_sec, before_mood, after_mood, meditation_name')
        .single();

    return MeditationSession.fromMap(response);
  }

  Future<MeditationSession> recordDailyMood({
    required DateTime timestamp,
    required MoodSessionType type,
    required String moodLabel,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('User must be authenticated to log mood.');
    }

    final dayStart = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final selection =
        'id, meditation_id, started_at, completed_at, duration_sec, before_mood, after_mood, meditation_name';

    Map<String, dynamic>? session;
    try {
      session = await _client
          .from('meditation_sessions')
          .select(selection)
          .eq('user_id', userId)
          .isFilter('meditation_id', null)
          .gte('started_at', dayStart.toUtc().toIso8601String())
          .lt('started_at', dayEnd.toUtc().toIso8601String())
          .limit(1)
          .maybeSingle();
    } catch (_) {
      session = null;
    }

    if (session == null) {
      final insertPayload = {
        'user_id': userId,
        'meditation_id': null,
        'started_at': dayStart.toUtc().toIso8601String(),
        'completed_at': dayStart.toUtc().toIso8601String(),
        'duration_sec': 0,
        if (type == MoodSessionType.before) 'before_mood': moodLabel,
        if (type == MoodSessionType.after) 'after_mood': moodLabel,
      };

      session = await _client
          .from('meditation_sessions')
          .insert(insertPayload)
          .select(selection)
          .single();
    } else {
      final updatePayload = <String, dynamic>{
        if (type == MoodSessionType.before) 'before_mood': moodLabel,
        if (type == MoodSessionType.after) 'after_mood': moodLabel,
      };

      session = await _client
          .from('meditation_sessions')
          .update(updatePayload)
          .eq('id', session['id'])
          .select(selection)
          .single();
    }

    return MeditationSession.fromMap(session);
  }

  /// Fetches all meditation sessions for a specific day
  Future<List<MeditationSession>> getSessionsForDay(DateTime day) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return [];
    }

    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final rows = await _client
        .from('meditation_sessions')
        .select(
            'id, meditation_id, started_at, completed_at, duration_sec, before_mood, after_mood, meditation_name')
        .eq('user_id', userId)
        .gte('started_at', dayStart.toUtc().toIso8601String())
        .lt('started_at', dayEnd.toUtc().toIso8601String())
        .order('started_at', ascending: false);

    final List data = rows as List;
    return data
        .whereType<Map<String, dynamic>>()
        .map(MeditationSession.fromMap)
        .toList();
  }
}

