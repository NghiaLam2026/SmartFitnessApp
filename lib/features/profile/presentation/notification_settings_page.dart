import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_client.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends ConsumerState<NotificationSettingsPage> {
  TimeOfDay _dailyMotivationTime = const TimeOfDay(hour: 8, minute: 0);
  bool _isLoading = false;
  bool _workoutMilestonesEnabled = true;
  bool _dailyMotivationEnabled = true;
  bool _achievementsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get user's notification preferences
      final prefs = await supabase.rpc(
        'get_notification_preferences',
        params: {'p_user_id': userId},
      ) as List;

      if (prefs.isNotEmpty && mounted) {
        final eventNotif = prefs.firstWhere(
          (p) => p['kind'] == 'event_notification',
          orElse: () => null,
        );

        if (eventNotif != null) {
          final timeStr = eventNotif['daily_motivation_time'] as String?;
          if (timeStr != null) {
            final parts = timeStr.split(':');
            setState(() {
              _dailyMotivationTime = TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              );
            });
          }
        }

        // Load other preferences
        if (mounted) {
          setState(() {
            _workoutMilestonesEnabled = prefs.any((p) => p['kind'] == 'achievement' && p['enabled'] == true);
            _dailyMotivationEnabled = prefs.any((p) => p['kind'] == 'event_notification' && p['enabled'] == true);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading preferences: $e')),
        );
      }
    }
  }

  Future<void> _updateDailyMotivationTime(TimeOfDay newTime) async {
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final timeString = '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}:00';

      final response = await supabase.rpc(
        'set_daily_motivation_time',
        params: {
          'p_user_id': userId,
          'p_time': timeString,
          'p_time_zone': 'UTC', // Could be user's timezone
        },
      );

      if (mounted) {
        setState(() => _dailyMotivationTime = newTime);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Daily motivation time set to ${newTime.format(context)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating time: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _dailyMotivationTime,
    );

    if (picked != null && picked != _dailyMotivationTime) {
      await _updateDailyMotivationTime(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Daily Motivation Section
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '☀️ Daily Motivation',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send at',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dailyMotivationTime.format(context),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _selectTime,
                        icon: const Icon(Icons.schedule),
                        label: const Text('Change Time'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Enable Daily Motivation'),
                    subtitle: const Text('Receive motivational reminders daily'),
                    value: _dailyMotivationEnabled,
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            setState(() => _dailyMotivationEnabled = value);
                            // TODO: Save preference to database
                          },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          // Workout Milestones Section
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💪 Workout Milestones',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Celebrate your fitness achievements',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Enable Milestone Notifications'),
                    subtitle: const Text('1st, 3rd, 5th, and every 10th workout'),
                    value: _workoutMilestonesEnabled,
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            setState(() => _workoutMilestonesEnabled = value);
                            // TODO: Save preference to database
                          },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          // Achievements Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🏆 Achievements',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Get notified when you earn badges and achievements',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Enable Achievement Notifications'),
                    value: _achievementsEnabled,
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            setState(() => _achievementsEnabled = value);
                            // TODO: Save preference to database
                          },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

