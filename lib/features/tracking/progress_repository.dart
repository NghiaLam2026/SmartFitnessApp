import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
//for health connect integration
import 'package:health/health.dart';
import 'package:flutter/foundation.dart';

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


//NEW sync health connect to supabase

  Future<void> synchHealthDataToSupabase() async {
    final Health health = Health();
    List<RecordingMethod> recordingMethodsToFilter = [];
    final user = _client.auth.currentUser;
    if (user == null ) throw Exception("User not logged in.");

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

  //define the data types you want to sync:
    final types = [
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
    ];

    bool requested = await health.requestAuthorization(types);
    if (!requested){
      throw Exception("Health data permission not granted.");

    }
    //declare outside of the try method 
    List<HealthDataPoint> healthData = [];
    try{

        healthData = await health.getHealthDataFromTypes(
        types: types,
        startTime: yesterday,
        endTime: now,
        recordingMethodsToFilter: recordingMethodsToFilter,

      );
      for (var point in healthData){
        debugPrint('Source: ${point.sourceName}, method: ${point.recordingMethod}');
      }
    } catch (e){
      debugPrint('Error fetching health data: $e');
    }


  //aggregate total
    double totalSteps = 0;
    double caloriesBurned = 0;

    for (var point in healthData){
      if (point.type == HealthDataType.STEPS){
        totalSteps += (point.value as num).toDouble();

      }else if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED){
        caloriesBurned += (point.value as num).toDouble();
      }
    }
  //insert or update progress in SupaBase
    double latestWeight = 0.0;
    await _client.from('user_progress').upsert({
      'user_id': user.id,
      'date_logged': now.toIso8601String(),
      'steps_count': totalSteps.round(),
      'weight': latestWeight,
      'calories_burned': caloriesBurned.round(),
   });
    debugPrint('Synched health Connect data to supabase!');
  }
}