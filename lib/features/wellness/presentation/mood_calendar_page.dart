import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../domain/mood_repository.dart';
import '../infrastructure/meditation_session_repository.dart';

class MoodCalendarPage extends StatefulWidget {
  const MoodCalendarPage({super.key});

  @override
  State<MoodCalendarPage> createState() => _MoodCalendarPageState();
}

class _MoodCalendarPageState extends State<MoodCalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _loading = true;
  String? _errorMessage;
  late final MeditationSessionRepository _sessionRepository;
  List<MeditationSession> _sessionsForSelectedDay = [];
  bool _loadingSessions = false;

  @override
  void initState() {
    super.initState();
    _sessionRepository = MeditationSessionRepository();
    _loadRecentMoods();
  }

  Future<void> _loadRecentMoods() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await MoodRepository.instance.loadRecent();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _selectedDay ??= DateTime.now();
        _focusedDay = _selectedDay!;
      });
      if (_selectedDay != null) {
        _loadSessionsForDay(_selectedDay!);
      }
    } catch (e) {
      debugPrint('Failed to load moods: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Unable to load mood history right now.';
      });
    }
  }

  Future<void> _loadSessionsForDay(DateTime day) async {
    setState(() {
      _loadingSessions = true;
    });

    try {
      final sessions = await _sessionRepository.getSessionsForDay(day);
      if (!mounted) return;
      setState(() {
        _sessionsForSelectedDay = sessions;
        _loadingSessions = false;
      });
    } catch (e) {
      debugPrint('Failed to load sessions: $e');
      if (!mounted) return;
      setState(() {
        _loadingSessions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Calendar'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _errorMessage!,
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadRecentMoods,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
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
                _loadSessionsForDay(selectedDay);
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedDay != null)
            Expanded(
              child: _buildSessionsList(theme, _selectedDay!),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(ThemeData theme, DateTime day) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
                '${_getMonthName(day.month)} ${day.day}, ${day.year}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showSessionPicker(context, day),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Log Mood'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_loadingSessions)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_sessionsForSelectedDay.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.self_improvement_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No sessions for this day',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Log Mood" to add a mood entry',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _sessionsForSelectedDay.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final session = _sessionsForSelectedDay[index];
                return _buildSessionCard(theme, session);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSessionCard(ThemeData theme, MeditationSession session) {
    final hasMeditation = session.meditationName != null && session.meditationName!.isNotEmpty;
    final duration = session.duration;
    final durationText = duration != null
        ? '${duration.inMinutes}m ${duration.inSeconds % 60}s'
        : 'Incomplete';
    final timeText = _formatTime(session.startedAt);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasMeditation ? Icons.spa_rounded : Icons.mood_outlined,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasMeditation
                            ? session.meditationName!
                            : 'Mood Entry',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          if (duration != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              durationText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (session.beforeMood != null || session.afterMood != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (session.beforeMood != null)
                _buildMoodRow(
                  theme,
                  'Before',
                  session.beforeMood!,
                  Icons.wb_sunny_outlined,
                ),
              if (session.afterMood != null) ...[
                if (session.beforeMood != null) const SizedBox(height: 8),
                _buildMoodRow(
                  theme,
                  'After',
                  session.afterMood!,
                  Icons.nightlight_round,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMoodRow(
    ThemeData theme,
    String label,
    String mood,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.6)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          mood,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
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
      onTap: () async {
        final now = DateTime.now();
        final timestamp = DateTime(
          day.year,
          day.month,
          day.day,
          now.hour,
          now.minute,
          now.second,
        );
        try {
          final session = await _sessionRepository.recordDailyMood(
            timestamp: timestamp,
            type: type,
            moodLabel: label,
          );

          MoodRepository.instance.applyMood(
            timestamp: session.startedAt,
            type: type,
            moodLabel: label,
          );

          if (context.mounted) {
        setState(() {});
        Navigator.of(context).pop();
          }
        } catch (e) {
          Navigator.of(context).pop();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to save mood. Please try again.')),
            );
          }
        }
      },
    );
  }
}

Future<String?> showMoodPicker(
      BuildContext context,
      DateTime day,
      MoodSessionType type,
      ) {
    final theme = Theme.of(context);

  return showModalBottomSheet<String>(
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
                style:
                    theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
              _globalMoodChoice(context, '😊 Great'),
              _globalMoodChoice(context, '🙂 Good'),
              _globalMoodChoice(context, '😐 Neutral'),
              _globalMoodChoice(context, '😕 Low'),
              _globalMoodChoice(context, '😞 Drained'),
              ],
            ),
          ),
        );
      },
    );
  }

Widget _globalMoodChoice(BuildContext context, String label) {
    return ListTile(
      title: Text(label),
    onTap: () => Navigator.of(context).pop(label),
    );
  }
