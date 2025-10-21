import 'package:supabase_flutter/supabase_flutter.dart';

class WorkoutRepository {
  final SupabaseClient _client = Supabase.instance.client;
  //Insert a new workout
  Future<void> addWorkout({
    required String title,
    required String category,
    required int durationMinutes,
    required int caloriesBurn,
    required bool isCompleted,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No logged-in user.');

    await _client.from('workouts').insert({
      'user_id': user.id,
      'title': title,
      'category': category,
      'duration_minutes':durationMinutes,
      'calories_burn_est': caloriesBurn,
      'is_completed': isCompleted,
    });
  }
  //fetch all workouts for the current user
  Future<List<Map<String, dynamic>>> fetchWorkouts() async{
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No logged-in user.');

    final response = await _client
      .from('workouts')
      .select('*')
      .eq('user_id', user.id)
      .order('date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

}