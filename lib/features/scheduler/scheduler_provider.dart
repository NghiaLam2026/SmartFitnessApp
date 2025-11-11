import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'scheduler_event.dart';
import 'scheduled_events_repository.dart';

int _hash(DateTime d) => d.day * 1_000_000 + d.month * 10_000 + d.year;
DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// State class to hold events and loading/error states
class SchedulerState {
  final LinkedHashMap<DateTime, List<SchedulerEvent>> events;
  final bool isLoading;
  final String? error;

  const SchedulerState({
    required this.events,
    this.isLoading = false,
    this.error,
  });

  SchedulerState copyWith({
    LinkedHashMap<DateTime, List<SchedulerEvent>>? events,
    bool? isLoading,
    String? error,
  }) {
    return SchedulerState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SchedulerController extends StateNotifier<SchedulerState> {
  final ScheduledEventsRepository _repository;

  SchedulerController({ScheduledEventsRepository? repository})
      : _repository = repository ?? ScheduledEventsRepository(),
        super(
          SchedulerState(
            events: LinkedHashMap<DateTime, List<SchedulerEvent>>(
              equals: isSameDay,
              hashCode: _hash,
            ),
          ),
        );

  /// Load events from the database
  Future<void> loadEvents({DateTime? startDate, DateTime? endDate}) async {
    if (state.isLoading) return; // Prevent concurrent loads

    state = state.copyWith(isLoading: true, error: null);

    try {
      final events = await _repository.fetchEvents(
        startDate: startDate,
        endDate: endDate,
      );

      final eventsMap = LinkedHashMap<DateTime, List<SchedulerEvent>>(
        equals: isSameDay,
        hashCode: _hash,
      );

      for (final event in events) {
        final k = _dayOnly(event.date);
        eventsMap.putIfAbsent(k, () => []).add(event);
      }

      state = state.copyWith(events: eventsMap, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load events: ${e.toString()}',
      );
      rethrow; // Re-throw so UI can handle it
    }
  }

  /// Load events for a specific month (optimized for calendar view)
  Future<void> loadEventsForMonth(DateTime month) async {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    await loadEvents(startDate: firstDay, endDate: lastDay);
  }

  List<SchedulerEvent> eventsFor(DateTime day) {
    final k = _dayOnly(day);
    return state.events[k] ?? const [];
  }

  /// Add a new event to the database
  Future<void> addEvent(DateTime day, String title, {String? note, String? workoutId}) async {
    try {
      // Validate workoutId if provided
      final validWorkoutId = (workoutId != null && workoutId.trim().isNotEmpty) 
          ? workoutId.trim() 
          : null;
      
      final newEvent = await _repository.createEvent(
        date: day,
        title: title,
        note: note,
        workoutId: validWorkoutId,
      );

      final k = _dayOnly(day);
      final list = List<SchedulerEvent>.from(state.events[k] ?? const []);
      list.add(newEvent);
      final updatedEvents = LinkedHashMap<DateTime, List<SchedulerEvent>>.from(state.events)
        ..[k] = list;

      state = state.copyWith(events: updatedEvents, error: null);
    } catch (e) {
      state = state.copyWith(error: 'Failed to add event: ${e.toString()}');
      rethrow;
    }
  }

  /// Remove an event from the database
  Future<void> removeEvent(DateTime day, String id) async {
    try {
      await _repository.deleteEvent(id);

      final k = _dayOnly(day);
      final list = List<SchedulerEvent>.from(state.events[k] ?? const [])
        ..removeWhere((x) => x.id == id);
      final updatedEvents = LinkedHashMap<DateTime, List<SchedulerEvent>>.from(state.events)
        ..[k] = list;

      state = state.copyWith(events: updatedEvents, error: null);
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete event: ${e.toString()}');
      rethrow;
    }
  }

  /// Update an existing event in the database
  Future<void> updateEvent(DateTime day, String id, String newTitle, {String? newNote, String? workoutId}) async {
    try {
      // Validate workoutId if provided
      final validWorkoutId = (workoutId != null && workoutId.trim().isNotEmpty) 
          ? workoutId.trim() 
          : null;
      
      await _repository.updateEvent(
        eventId: id,
        title: newTitle,
        note: newNote,
        workoutId: validWorkoutId,
      );

      final k = _dayOnly(day);
      final list = List<SchedulerEvent>.from(state.events[k] ?? const []);
      final index = list.indexWhere((x) => x.id == id);
      if (index != -1) {
        final existingEvent = list[index];
        list[index] = SchedulerEvent(
          id: id,
          date: day,
          title: newTitle,
          note: newNote,
          workoutId: workoutId ?? existingEvent.workoutId,
          workoutTitle: existingEvent.workoutTitle, // Keep existing title until reload
        );
        final updatedEvents = LinkedHashMap<DateTime, List<SchedulerEvent>>.from(state.events)
          ..[k] = list;

        state = state.copyWith(events: updatedEvents, error: null);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to update event: ${e.toString()}');
      rethrow;
    }
  }

  /// Clear any error state
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }
}

/// Provider for scheduler state management
final schedulerProvider = StateNotifierProvider<SchedulerController, SchedulerState>(
  (ref) => SchedulerController(),
);
