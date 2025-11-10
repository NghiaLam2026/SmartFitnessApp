import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'scheduler_event.dart';

int _hash(DateTime d) => d.day * 1_000_000 + d.month * 10_000 + d.year;
DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class SchedulerController
    extends StateNotifier<LinkedHashMap<DateTime, List<SchedulerEvent>>> {
  SchedulerController()
    : super(
        LinkedHashMap<DateTime, List<SchedulerEvent>>(
          equals: isSameDay,
          hashCode: _hash,
        ),
      );

  List<SchedulerEvent> eventsFor(DateTime day) {
    final k = _dayOnly(day);
    return state[k] ?? const [];
  }

  void addEvent(DateTime day, SchedulerEvent e) {
    final k = _dayOnly(day);
    final list = List<SchedulerEvent>.from(state[k] ?? const []);
    list.add(e);
    state = LinkedHashMap<DateTime, List<SchedulerEvent>>.from(state)
      ..[k] = list;
  }

  void removeEvent(DateTime day, String id) {
    final k = _dayOnly(day);
    final list = List<SchedulerEvent>.from(state[k] ?? const [])
      ..removeWhere((x) => x.id == id);
    state = LinkedHashMap<DateTime, List<SchedulerEvent>>.from(state)
      ..[k] = list;
  }
}

final schedulerProvider =
    StateNotifierProvider<
      SchedulerController,
      LinkedHashMap<DateTime, List<SchedulerEvent>>
    >((ref) => SchedulerController());
