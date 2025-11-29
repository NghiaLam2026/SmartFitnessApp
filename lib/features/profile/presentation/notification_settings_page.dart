import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/notification_service.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends ConsumerState<NotificationSettingsPage> {
  TimeOfDay _motivationTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('motivation_hour') ?? 9;
    final minute = prefs.getInt('motivation_minute') ?? 0;
    
    if (mounted) {
      setState(() {
        _motivationTime = TimeOfDay(hour: hour, minute: minute);
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTime(TimeOfDay time) async {
    setState(() => _isLoading = true);
    
    // Save to prefs
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('motivation_hour', time.hour);
    await prefs.setInt('motivation_minute', time.minute);

    // Schedule the notification
    await NotificationService.instance.scheduleDailyMotivation(
      hour: time.hour, 
      minute: time.minute
    );

    if (mounted) {
      setState(() {
        _motivationTime = time;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Daily motivation set for ${time.format(context)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  title: const Text('Daily Motivation'),
                  subtitle: Text('Schedule your daily boost at ${_motivationTime.format(context)}'),
                  trailing: const Icon(Icons.access_time_rounded),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _motivationTime,
                    );
                    if (time != null) {
                      _saveTime(time);
                    }
                  },
                ),
              ],
            ),
    );
  }
}

