import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import 'scheduler_event.dart';

/// Repository for managing scheduled events in the database
class ScheduledEventsRepository {
  final SupabaseClient _client;

  ScheduledEventsRepository({SupabaseClient? client}) : _client = client ?? supabase;

  /// Create a new scheduled event
  Future<SchedulerEvent> createEvent({
    required DateTime date,
    required String title,
    String? note,
    String? workoutId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated. Please sign in to create events.');
    }

    if (title.trim().isEmpty) {
      throw Exception('Event title cannot be empty.');
    }

    final dayOnly = DateTime(date.year, date.month, date.day);

    try {
      final insertData = <String, dynamic>{
        'user_id': user.id,
        'date': dayOnly.toIso8601String().split('T')[0], // Format as YYYY-MM-DD
        'title': title.trim(),
        'note': note?.trim().isEmpty ?? false ? null : note?.trim(),
      };
      
      // Only add workout_id if it's not null and not empty
      if (workoutId != null && workoutId.trim().isNotEmpty) {
        insertData['workout_id'] = workoutId.trim();
      }

      final response = await _client
          .from('scheduled_events')
          .insert(insertData)
          .select()
          .single();

      // Fetch workout title if workout_id is present
      String? workoutTitle;
      if (workoutId != null) {
        try {
          final workoutResponse = await _client
              .from('workouts')
              .select('title')
              .eq('id', workoutId)
              .maybeSingle();
          if (workoutResponse != null) {
            workoutTitle = workoutResponse['title'] as String?;
          }
        } catch (_) {
          // Workout might not exist, continue without title
        }
      }

      final eventMap = Map<String, dynamic>.from(response);
      if (workoutTitle != null) {
        eventMap['workout_title'] = workoutTitle;
      }

      return SchedulerEvent.fromMap(eventMap);
    } catch (e) {
      throw Exception('Failed to create event: ${e.toString()}');
    }
  }

  /// Fetch all events for a specific date range
  Future<List<SchedulerEvent>> fetchEvents({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Build query with filters before ordering
    dynamic query = _client
        .from('scheduled_events')
        .select()
        .eq('user_id', user.id);

    if (startDate != null) {
      final startDateStr = DateTime(startDate.year, startDate.month, startDate.day)
          .toIso8601String()
          .split('T')[0];
      query = query.gte('date', startDateStr);
    }

    if (endDate != null) {
      final endDateStr = DateTime(endDate.year, endDate.month, endDate.day)
          .toIso8601String()
          .split('T')[0];
      query = query.lte('date', endDateStr);
    }

    // Apply ordering after all filters
    query = query.order('date', ascending: true);

    final response = await query;
    final List data = response;
    
    // Fetch workout titles for events that have workout_id
    final eventsWithWorkouts = <String>[];
    for (final item in data) {
      final eventMap = item as Map<String, dynamic>;
      final workoutId = eventMap['workout_id'] as String?;
      if (workoutId != null && !eventsWithWorkouts.contains(workoutId)) {
        eventsWithWorkouts.add(workoutId);
      }
    }

    // Fetch all workout titles in one query
    final Map<String, String> workoutTitles = {};
    if (eventsWithWorkouts.isNotEmpty) {
      try {
        dynamic qb = _client
            .from('workouts')
            .select('id, title');
        
        // Use in_ filter if list is small, otherwise use or() as fallback
        if (eventsWithWorkouts.length == 1) {
          qb = qb.eq('id', eventsWithWorkouts.first);
        } else {
          try {
            qb = qb.in_('id', eventsWithWorkouts);
          } catch (_) {
            // Fallback: use or() method if in_ fails
            final orExpr = eventsWithWorkouts.map((id) => 'id.eq.$id').join(',');
            qb = qb.or(orExpr);
          }
        }
        
        final workoutsResponse = await qb;
        final List workoutsList = workoutsResponse;
        
        for (final workout in workoutsList) {
          final workoutMap = workout as Map<String, dynamic>;
          final id = workoutMap['id'] as String;
          final title = workoutMap['title'] as String?;
          if (title != null) {
            workoutTitles[id] = title;
          }
        }
      } catch (_) {
        // Continue without workout titles if fetch fails
      }
    }
    
    // Process each event and add workout title
    return data.map((item) {
      final eventMap = Map<String, dynamic>.from(item as Map<String, dynamic>);
      final workoutId = eventMap['workout_id'] as String?;
      if (workoutId != null && workoutTitles.containsKey(workoutId)) {
        eventMap['workout_title'] = workoutTitles[workoutId];
      }
      return SchedulerEvent.fromMap(eventMap);
    }).toList();
  }

  /// Fetch events for a specific day
  Future<List<SchedulerEvent>> fetchEventsForDay(DateTime day) async {
    final dayOnly = DateTime(day.year, day.month, day.day);
    final dayStr = dayOnly.toIso8601String().split('T')[0];

    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await _client
        .from('scheduled_events')
        .select()
        .eq('user_id', user.id)
        .eq('date', dayStr)
        .order('created_at', ascending: true);

    final List data = response;
    
    // Fetch workout titles for events that have workout_id
    final eventsWithWorkouts = <String>[];
    for (final item in data) {
      final eventMap = item as Map<String, dynamic>;
      final workoutId = eventMap['workout_id'] as String?;
      if (workoutId != null && !eventsWithWorkouts.contains(workoutId)) {
        eventsWithWorkouts.add(workoutId);
      }
    }

    // Fetch all workout titles in one query
    final Map<String, String> workoutTitles = {};
    if (eventsWithWorkouts.isNotEmpty) {
      try {
        dynamic qb = _client
            .from('workouts')
            .select('id, title');
        
        // Use in_ filter if list is small, otherwise use or() as fallback
        if (eventsWithWorkouts.length == 1) {
          qb = qb.eq('id', eventsWithWorkouts.first);
        } else {
          try {
            qb = qb.in_('id', eventsWithWorkouts);
          } catch (_) {
            // Fallback: use or() method if in_ fails
            final orExpr = eventsWithWorkouts.map((id) => 'id.eq.$id').join(',');
            qb = qb.or(orExpr);
          }
        }
        
        final workoutsResponse = await qb;
        final List workoutsList = workoutsResponse;
        
        for (final workout in workoutsList) {
          final workoutMap = workout as Map<String, dynamic>;
          final id = workoutMap['id'] as String;
          final title = workoutMap['title'] as String?;
          if (title != null) {
            workoutTitles[id] = title;
          }
        }
      } catch (_) {
        // Continue without workout titles if fetch fails
      }
    }
    
    // Process each event and add workout title
    return data.map((item) {
      final eventMap = Map<String, dynamic>.from(item as Map<String, dynamic>);
      final workoutId = eventMap['workout_id'] as String?;
      if (workoutId != null && workoutTitles.containsKey(workoutId)) {
        eventMap['workout_title'] = workoutTitles[workoutId];
      }
      return SchedulerEvent.fromMap(eventMap);
    }).toList();
  }

  /// Update an existing event
  Future<void> updateEvent({
    required String eventId,
    required String title,
    String? note,
    String? workoutId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated. Please sign in to update events.');
    }

    if (title.trim().isEmpty) {
      throw Exception('Event title cannot be empty.');
    }

    if (eventId.isEmpty) {
      throw Exception('Event ID is required.');
    }

    try {
      final updateData = <String, dynamic>{
        'title': title.trim(),
        'note': note?.trim().isEmpty ?? false ? null : note?.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Handle workout_id: set to null if empty string, otherwise set the value
      if (workoutId == null || workoutId.trim().isEmpty) {
        updateData['workout_id'] = null;
      } else {
        updateData['workout_id'] = workoutId.trim();
      }

      await _client
          .from('scheduled_events')
          .update(updateData)
          .eq('id', eventId)
          .eq('user_id', user.id);
    } catch (e) {
      throw Exception('Failed to update event: ${e.toString()}');
    }
  }

  /// Delete an event
  Future<void> deleteEvent(String eventId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated. Please sign in to delete events.');
    }

    if (eventId.isEmpty) {
      throw Exception('Event ID is required.');
    }

    try {
      await _client
          .from('scheduled_events')
          .delete()
          .eq('id', eventId)
          .eq('user_id', user.id);
    } catch (e) {
      throw Exception('Failed to delete event: ${e.toString()}');
    }
  }
}

