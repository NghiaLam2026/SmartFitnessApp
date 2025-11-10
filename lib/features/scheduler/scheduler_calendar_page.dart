import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'scheduler_event.dart';
import 'scheduler_provider.dart';

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

  void _addEventForSelectedDay(String title, {String? note}) {
    final dayOnly = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );

    ref
        .read(schedulerProvider.notifier)
        .addEvent(
          dayOnly,
          SchedulerEvent(
            id: 'evt_${Random().nextInt(1 << 31)}',
            date: dayOnly,
            title: title,
            note: note,
          ),
        );

    setState(() {}); // refresh UI
  }

  Future<void> _promptNewEvent() async {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed == true && titleCtrl.text.trim().isNotEmpty) {
      _addEventForSelectedDay(
        titleCtrl.text.trim(),
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch provider so widget rebuilds when events change
    ref.watch(schedulerProvider);

    final scheduler = ref.read(schedulerProvider.notifier);
    final events = scheduler.eventsFor(_selectedDay);

    return Scaffold(
      appBar: AppBar(title: const Text('Scheduler Calendar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _promptNewEvent,
        icon: const Icon(Icons.add),
        label: const Text('New Event'),
      ),
      body: Column(
        children: [
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
            onPageChanged: (f) => _focusedDay = f,
            eventLoader: (day) => scheduler.eventsFor(day),
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
            ),
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent,
              ),
              selectedDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
              ),
              markerDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: events.isEmpty
                ? const Center(child: Text('No events for this day yet.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final e = events[index];
                      return Dismissible(
                        key: ValueKey(e.id),
                        background: Container(
                          color: Colors.redAccent,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        direction: DismissDirection.startToEnd,
                        onDismissed: (_) {
                          scheduler.removeEvent(e.date, e.id);
                          setState(() {});
                        },
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.event),
                            title: Text(e.title),
                            subtitle: e.note == null ? null : Text(e.note!),
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
