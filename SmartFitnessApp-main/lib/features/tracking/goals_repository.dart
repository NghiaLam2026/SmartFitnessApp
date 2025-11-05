import 'package:supabase_flutter/supabase_flutter.dart';

class GoalsRepository{
  final SupabaseClient _client = Supabase.instance.client;
  //Add a new goal
  Future <void> addGoal({
    required String goalType,
    required int targetValue,
    DateTime? endDate,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception ('No logged-in user.');

    await _client.from('goals').insert({
      'user_id': user.id,
      'goal_type': goalType,
      'target_value': targetValue,
      'end_date': endDate?.toIso8601String(),
    });
  }
  //fetch all active goals
  Future<List<Map<String,dynamic>>> fetchActiveGoals() async{
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No logged-in user.');

    final response = await _client
      .from('goals')
      .select('*')
      .eq('user_id', user.id)
      .order('end_date', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }
  //update progress
  Future<void> updateProgress(String goalId, int currentValue) async{
    await _client.from('goals').update({
      'current_value': currentValue,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('goal_id', goalId);
  }
}