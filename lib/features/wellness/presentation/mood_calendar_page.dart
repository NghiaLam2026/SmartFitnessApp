import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../domain/mood_repository.dart';

class MoodCalendarPage extends StatefulWidget {
  const MoodCalendarPage({super.key});

  @override
  State<MoodCalendarPage> createState() => _MoodCalendarPageState();
}

class _MoodCalendarPageState extends State<MoodCalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedEntry = _selectedDay == null
        ? null
        : MoodRepository.instance.getEntryForDay(_selectedDay!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Calendar'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2100, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              selectedDayPredicate: (day) =>
              _selectedDay != null &&
                  day.year == _selectedDay!.year &&
                  day.month == _selectedDay!.month &&
                  day.day == _selectedDay!.day,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _showSessionPicker(context, selectedDay);
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedDay != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSelectedDaySummary(theme, _selectedDay!, selectedEntry),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedDaySummary(
      ThemeData theme,
      DateTime day,
      MoodEntry? entry,
      ) {
    if (entry == null || (entry.beforeMood == null && entry.afterMood == null)) {
      return Text(
        'No mood logged yet for '
            '${day.month}/${day.day}/${day.year}.\n'
            'Tap a date and choose Before or After Session.',
        style: theme.textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mood for ${day.month}/${day.day}/${day.year}',
          style:
          theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (entry.beforeMood != null)
          Text('Before session: ${entry.beforeMood}'),
        if (entry.afterMood != null)
          Text('After session: ${entry.afterMood}'),
      ],
    );
  }

  void _showSessionPicker(BuildContext context, DateTime day) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Log mood for ${day.month}/${day.day}/${day.year}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Before session'),
                  subtitle: const Text('How you felt before meditation'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showMoodPicker(
                      context,
                      day,
                      MoodSessionType.before,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.nightlight_round),
                  title: const Text('After session'),
                  subtitle: const Text('How you felt after meditation'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showMoodPicker(
                      context,
                      day,
                      MoodSessionType.after,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoodPicker(
      BuildContext context,
      DateTime day,
      MoodSessionType type,
      ) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              runSpacing: 8,
              children: [
                Text(
                  type == MoodSessionType.before
                      ? 'How do you feel before your session?'
                      : 'How do you feel after your session?',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                _buildMoodChoice(context, day, type, '😊 Great'),
                _buildMoodChoice(context, day, type, '🙂 Good'),
                _buildMoodChoice(context, day, type, '😐 Neutral'),
                _buildMoodChoice(context, day, type, '😕 Low'),
                _buildMoodChoice(context, day, type, '😞 Drained'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoodChoice(
      BuildContext context,
      DateTime day,
      MoodSessionType type,
      String label,
      ) {
    return ListTile(
      title: Text(label),
      onTap: () {
        MoodRepository.instance.setMood(day, type, label);
        setState(() {});
        Navigator.of(context).pop();
      },
    );
  }
}
 void showMoodPicker(
      BuildContext context,
      DateTime day,
      MoodSessionType type,
      ) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              runSpacing: 8,
              children: [
                Text(
                  type == MoodSessionType.before
                      ? 'How do you feel before your session?'
                      : 'How do you feel after your session?',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                buildMoodChoice(context, day, type, '😊 Great'),
                buildMoodChoice(context, day, type, '🙂 Good'),
                buildMoodChoice(context, day, type, '😐 Neutral'),
                buildMoodChoice(context, day, type, '😕 Low'),
                buildMoodChoice(context, day, type, '😞 Drained'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildMoodChoice(
      BuildContext context,
      DateTime day,
      MoodSessionType type,
      String label,
      ) {
    return ListTile(
      title: Text(label),
      onTap: () {
        MoodRepository.instance.setMood(day, type, label);
        Navigator.of(context).pop();
      },
    );
  }
