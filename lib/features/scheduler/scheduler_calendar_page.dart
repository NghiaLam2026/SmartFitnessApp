import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'scheduler_event.dart';
import 'scheduler_provider.dart';
import 'widgets/workout_selector_widget.dart';

class SchedulerCalendarPage extends ConsumerStatefulWidget {
  const SchedulerCalendarPage({super.key});

  @override
  ConsumerState<SchedulerCalendarPage> createState() =>
      _SchedulerCalendarPageState();
}

class _SchedulerCalendarPageState extends ConsumerState<SchedulerCalendarPage> {
  CalendarFormat _format = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  DateTime? _lastLoadedMonth;

  @override
  void initState() {
    super.initState();
    // Load events for the current month on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEventsForCurrentMonth();
    });
  }

  Future<void> _loadEventsForCurrentMonth() async {
    if (!mounted) return;
    
    final currentMonth = DateTime(_focusedDay.year, _focusedDay.month);
    if (_lastLoadedMonth != currentMonth) {
      try {
        await ref.read(schedulerProvider.notifier).loadEventsForMonth(_focusedDay);
        if (mounted) {
          _lastLoadedMonth = currentMonth;
        }
      } catch (e) {
        // Error is handled in provider state
        if (mounted && e.toString().isNotEmpty) {
          // Only show if it's a meaningful error
        }
      }
    }
  }

  Future<void> _addEventForSelectedDay(String title, {String? note, String? workoutId}) async {
    if (title.trim().isEmpty) return;

    final dayOnly = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );

    try {
      await ref.read(schedulerProvider.notifier).addEvent(
            dayOnly,
            title.trim(),
            note: note?.trim(),
            workoutId: workoutId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event added successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Error is already handled in the provider state
      // Just show a user-friendly message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add event: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _promptNewEvent() async {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    // Use a mutable reference that can be updated from within the dialog
    String? selectedWorkoutId;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) {
        // Create a local variable that will be captured
        String? dialogWorkoutId;
        
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Add Event'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: 'Note (optional)'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  WorkoutSelectorWidget(
                    selectedWorkoutId: dialogWorkoutId,
                    onWorkoutSelected: (workoutId) {
                      setState(() {
                        dialogWorkoutId = workoutId;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  // Return both confirmation and the selected workout ID
                  Navigator.pop(ctx, {
                    'confirmed': true,
                    'workoutId': dialogWorkoutId,
                  });
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && 
        result['confirmed'] == true && 
        titleCtrl.text.trim().isNotEmpty) {
      _addEventForSelectedDay(
        titleCtrl.text.trim(),
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        workoutId: result['workoutId'] as String?,
      );
    }
  }

  Future<void> _promptEditEvent(SchedulerEvent event) async {
    final titleCtrl = TextEditingController(text: event.title);
    final noteCtrl = TextEditingController(text: event.note ?? '');

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) {
        // Use the event's current workout ID as initial value
        String? dialogWorkoutId = event.workoutId;
        
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Edit Event'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: 'Note (optional)'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  WorkoutSelectorWidget(
                    selectedWorkoutId: dialogWorkoutId,
                    onWorkoutSelected: (workoutId) {
                      setState(() {
                        dialogWorkoutId = workoutId;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  // Return both confirmation and the selected workout ID
                  Navigator.pop(ctx, {
                    'confirmed': true,
                    'workoutId': dialogWorkoutId,
                  });
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && 
        result['confirmed'] == true && 
        titleCtrl.text.trim().isNotEmpty) {
      try {
        await ref.read(schedulerProvider.notifier).updateEvent(
              event.date,
              event.id,
              titleCtrl.text.trim(),
              newNote: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              workoutId: result['workoutId'] as String?,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update event: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteEvent(SchedulerEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(schedulerProvider.notifier).removeEvent(event.date, event.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete event: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch provider so widget rebuilds when events change
    final schedulerState = ref.watch(schedulerProvider);
    final scheduler = ref.read(schedulerProvider.notifier);
    final events = scheduler.eventsFor(_selectedDay);

    // Show error message if there's an error (only once per error)
    if (schedulerState.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && schedulerState.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(schedulerState.error!),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {
                  scheduler.clearError();
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduler'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: schedulerState.isLoading ? null : _promptNewEvent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Event'),
      ),
      body: Column(
        children: [
          if (schedulerState.isLoading)
            const LinearProgressIndicator(),
          TableCalendar<SchedulerEvent>(
            firstDay: DateTime.utc(2010, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _format,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (f) => setState(() => _format = f),
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
              // Load events for the new month when calendar page changes
              _loadEventsForCurrentMonth();
            },
            eventLoader: (day) => scheduler.eventsFor(day),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left_rounded,
                color: Colors.grey.shade700,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade700,
              ),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primaryContainer,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              selectedDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              markerDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.error,
              ),
              defaultTextStyle: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
              weekendTextStyle: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              todayTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              outsideTextStyle: TextStyle(
                color: Colors.grey.shade400,
              ),
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.grey.shade200,
          ),
          Expanded(
            child: events.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_note_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No events for this day',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final e = events[index];
                      return Dismissible(
                        key: ValueKey(e.id),
                        background: Container(
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        direction: DismissDirection.startToEnd,
                        onDismissed: (_) async {
                          try {
                            await scheduler.removeEvent(e.date, e.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Event deleted')),
                              );
                            }
                          } catch (error) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to delete: ${error.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            // Rebuild to restore the item if deletion failed
                            setState(() {});
                          }
                        },
                        child: Card(
                          margin: EdgeInsets.zero,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        e.title,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    // Action buttons
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20),
                                          onPressed: () => _promptEditEvent(e),
                                          tooltip: 'Edit event',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          color: Colors.grey.shade700,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20),
                                          onPressed: () => _confirmDeleteEvent(e),
                                          tooltip: 'Delete event',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          color: Colors.redAccent,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Workout link (if present)
                                if (e.workoutTitle != null) ...[
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.fitness_center_rounded,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          e.workoutTitle!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (e.note != null) const SizedBox(height: 6),
                                ],
                                // Note (if present)
                                if (e.note != null)
                                  Text(
                                    e.note!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      height: 1.4,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
