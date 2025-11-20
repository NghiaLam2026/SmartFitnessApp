import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';

class ProgressRepository {
  final SupabaseClient _client;

  ProgressRepository({SupabaseClient? client}) : _client = client ?? supabase;

  //add a new progress entry steps calories and weight

  Future<void> addProgress({
    required double weight,
    required int caloriesBurned,
    required int stepsCount,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("User not logged in.");

    await _client.from('user_progress').insert({
      'user_id': user.id,
      'weight': weight,
      'calories_burned': caloriesBurned,
      'steps_count': stepsCount,
      //date_looged defaults to NOW() in supabase
    });

    // Process pending notifications for this user (milestone triggers)
    try {
      await _client.rpc('process_notification_jobs');
    } catch (e) {
      print('⚠️ Error processing notifications: $e');
      // Don't throw - notifications shouldn't block workout logging
    }
  }

  //Fetch all progress progress entries for current user
  Future<List<Map<String, dynamic>>> getProgress() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final response = await _client
        .from('user_progress')
        .select()
        .eq('user_id', user.id)
        .order('date_logged', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> upsertTodayProgress({

    required double weight,
    required int caloriesBurned,
    required int stepsCount,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("User not logged in.");

    final today = DateTime.now();
    final dateOnly = DateTime(today.year, today.month, today.day)
        .toIso8601String()
        .substring(0, 10);

    final response = await _client
        .from('user_progress')
        .upsert({
      'user_id': user.id,
      'date_logged': dateOnly,
      'weight': weight,
      'calories_burned': caloriesBurned,
      'steps_count': stepsCount,
    }, onConflict: 'user_id,date_logged')
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

//update a specific progress record

  Future<void> updateProgress(int progressId, double weight, int caloriesBurned,
      int stepsCount) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    await _client.from('user_progress').update({
      'weight': weight,
      'calories_burned': caloriesBurned,
      'steps_count': stepsCount,

    }).eq('progress_id', progressId).eq('user_id', user.id);
  }
}