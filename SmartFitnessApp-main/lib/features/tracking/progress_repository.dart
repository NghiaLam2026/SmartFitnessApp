import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';

class ProgressRepository {
  final SupabaseClient _client;

  ProgressRepository({SupabaseClient? client}) : _client = client ?? supabase;

  //Add a new progress entry
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
    });
  }
  //fetch all progress entries for the current user
  Future<List<Map<String, dynamic>>> getProgress() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception ("User not logged in");

    final response = await _client
      .from('user_progress')
      .select()
      .eq('user_id', user.id)
      .order('date_logged', ascending: false);
    return List<Map<String, dynamic>>.from(response);

  }
  //update a specific progress record if needed
  Future<void> updateProgress(int progressId, double weight, int caloriesBurned, int stepsCount) async{
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("User not logged in.");

    await _client.from('user_progress').update({
      'weight': weight,
      'calories_burned': caloriesBurned,
      'steps_count': stepsCount,
    }).eq('progress_id', progressId).eq('user_id', user.id);
  }
}