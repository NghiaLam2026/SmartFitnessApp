import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/workout_models.dart';

/// Repository interface for workout plans management
abstract class WorkoutRepository {
  Future<String> createWorkoutPlan(WorkoutPlan plan);
  Future<WorkoutPlan?> fetchWorkoutPlanById(String id);
  Future<List<WorkoutPlan>> fetchUserWorkoutPlans(String userId);
  Future<void> updateWorkoutPlan(WorkoutPlan plan);
  Future<void> deleteWorkoutPlan(String id);
  Future<void> addExerciseToWorkout(String workoutPlanId, WorkoutExercise exercise);
  Future<void> removeExerciseFromWorkout(String workoutExerciseId);
  Future<void> updateExerciseInWorkout(WorkoutExercise exercise);
}

class SupabaseWorkoutRepository implements WorkoutRepository {
  final SupabaseClient _client;

  SupabaseWorkoutRepository({SupabaseClient? client}) : _client = client ?? supabase;

  @override
  Future<String> createWorkoutPlan(WorkoutPlan plan) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Insert workout plan using 'workouts' table (plan_id = null means it's a template/plan)
    final response = await _client
        .from('workouts')
        .insert({
          'id': plan.id,
          'title': plan.title,
          'user_id': user.id,
          'plan_id': null, // null means this is a workout plan template
          'status': 'planned',
          // Store description and is_ai_generated in a metadata JSON field if needed
          // For now, we'll use description as title if title is empty
        })
        .select('id')
        .single();

    final planId = response['id'] as String;

    // Insert exercises
    for (final exercise in plan.exercises) {
      await _addExerciseToWorkout(planId, exercise);
    }

    return planId;
  }

  @override
  Future<WorkoutPlan?> fetchWorkoutPlanById(String id) async {
    try {
      final response = await _client
          .from('workouts')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      
      // Filter for workout plans (templates) where plan_id is null
      if (response['plan_id'] != null) return null;

      // Map response to WorkoutPlan format
      // workouts table doesn't have created_at, so we use scheduled_at or current time
      final mappedResponse = {
        'id': response['id'],
        'title': response['title'] ?? '',
        'description': null, // workouts table doesn't have description
        'user_id': response['user_id'],
        'created_at': (response['scheduled_at'] != null 
            ? (response['scheduled_at'] is String 
                ? response['scheduled_at'] 
                : (response['scheduled_at'] as DateTime).toIso8601String())
            : DateTime.now().toIso8601String()),
        'updated_at': null,
        'is_ai_generated': false, // workouts table doesn't have this field
      };

      // Fetch exercises for this workout
      final exercises = await fetchWorkoutExercises(id);

      return WorkoutPlan.fromMap(mappedResponse, exercises);
    } catch (e) {
      // Log error for debugging
      print('Error fetching workout plan: $e');
      rethrow;
    }
  }

  @override
  Future<List<WorkoutPlan>> fetchUserWorkoutPlans(String userId) async {
    final response = await _client
        .from('workouts')
        .select('*')
        .eq('user_id', userId)
        .order('scheduled_at', ascending: false);

    final List plans = response;
    
    // Filter for workout plans (templates) where plan_id is null
    final filteredPlans = plans.where((plan) => (plan as Map<String, dynamic>)['plan_id'] == null).toList();

    // Fetch exercises for each plan
    final workoutPlans = <WorkoutPlan>[];
    for (final planData in filteredPlans) {
      // Map response to WorkoutPlan format
      final mappedData = {
        'id': planData['id'],
        'title': planData['title'] ?? '',
        'description': null, // workouts table doesn't have description
        'user_id': planData['user_id'],
        'created_at': planData['scheduled_at'] ?? planData['created_at'] ?? DateTime.now().toIso8601String(),
        'updated_at': null,
        'is_ai_generated': false, // workouts table doesn't have this field
      };
      
      final plan = WorkoutPlan.fromMap(
        mappedData,
        await fetchWorkoutExercises(planData['id'] as String),
      );
      workoutPlans.add(plan);
    }

    return workoutPlans;
  }

  @override
  Future<void> updateWorkoutPlan(WorkoutPlan plan) async {
    // Update workout title
    await _client
        .from('workouts')
        .update({
          'title': plan.title,
          // workouts table doesn't have description or updated_at
        })
        .eq('id', plan.id);

    // Delete all existing exercises and sets for this workout
    // This ensures we have a clean slate
    await _client
        .from('workout_sets')
        .delete()
        .eq('workout_id', plan.id);
    
    await _client
        .from('workout_exercises')
        .delete()
        .eq('workout_id', plan.id);

    // Re-create all exercises with their sets
    for (final exercise in plan.exercises) {
      await _addExerciseToWorkout(plan.id, exercise);
    }
  }

  @override
  Future<void> deleteWorkoutPlan(String id) async {
    // Cascade deletion will handle workout_exercises and workout_sets
    // But being explicit for clarity
    // Delete sets first
    await _client
        .from('workout_sets')
        .delete()
        .eq('workout_id', id);

    // Delete workout exercises
    await _client
        .from('workout_exercises')
        .delete()
        .eq('workout_id', id);

    // Delete workout plan
    await _client.from('workouts').delete().eq('id', id);
  }

  @override
  Future<void> addExerciseToWorkout(String workoutPlanId, WorkoutExercise exercise) async {
    await _addExerciseToWorkout(workoutPlanId, exercise);
  }

  Future<void> _addExerciseToWorkout(String workoutPlanId, WorkoutExercise exercise) async {
    String? workoutExerciseId;
    
    // Try new structure first (workout_exercises table)
    try {
      final exerciseResponse = await _client
          .from('workout_exercises')
          .insert({
            'id': exercise.id,
            'workout_id': workoutPlanId,
            'exercise_id': exercise.exerciseId,
            'exercise_name': exercise.exerciseName,
            'order_index': exercise.orderIndex,
            'rest_seconds': exercise.restSeconds,
            'notes': exercise.notes,
          })
          .select('id')
          .single();

      workoutExerciseId = exerciseResponse['id'] as String;
    } catch (e) {
      // workout_exercises table doesn't exist - use fallback
      // workoutExerciseId will remain null, we'll use old structure
    }

    // Insert sets into workout_sets table
    // Note: The database will auto-generate UUIDs for the id field
    for (int i = 0; i < exercise.sets.length; i++) {
      final set = exercise.sets[i];
      final insertData = <String, dynamic>{
        // 'id' is auto-generated by database
        'workout_id': workoutPlanId,
        'exercise_id': exercise.exerciseId,
        'order_index': exercise.orderIndex,
        'target_reps': set.reps,
        'target_weight': set.weight,
        'target_time_sec': set.durationSeconds,
      };
      
      // Only add workout_exercise_id if we have it (new structure)
      if (workoutExerciseId != null) {
        insertData['workout_exercise_id'] = workoutExerciseId;
      }
      
      await _client.from('workout_sets').insert(insertData);
    }
  }

  @override
  Future<void> removeExerciseFromWorkout(String workoutExerciseId) async {
    // workoutExerciseId is the id from workout_exercises table
    // Delete sets first (cascade should handle this, but being explicit)
    await _client
        .from('workout_sets')
        .delete()
        .eq('workout_exercise_id', workoutExerciseId);

    // Delete the workout exercise entry
    await _client
        .from('workout_exercises')
        .delete()
        .eq('id', workoutExerciseId);
  }

  @override
  Future<void> updateExerciseInWorkout(WorkoutExercise exercise) async {
    // Update workout_exercise metadata
    await _client
        .from('workout_exercises')
        .update({
          'exercise_id': exercise.exerciseId,
          'exercise_name': exercise.exerciseName,
          'order_index': exercise.orderIndex,
          'rest_seconds': exercise.restSeconds,
          'notes': exercise.notes,
        })
        .eq('id', exercise.id);

    // Update sets (delete old, insert new)
    await _client
        .from('workout_sets')
        .delete()
        .eq('workout_exercise_id', exercise.id);

    // Insert new sets
    // Note: The database will auto-generate UUIDs for the id field
    for (int i = 0; i < exercise.sets.length; i++) {
      final set = exercise.sets[i];
      await _client
          .from('workout_sets')
          .insert({
            // 'id' is auto-generated by database
            'workout_id': exercise.workoutPlanId,
            'workout_exercise_id': exercise.id,
            'exercise_id': exercise.exerciseId,
            'order_index': exercise.orderIndex,
            'target_reps': set.reps,
            'target_weight': set.weight,
            'target_time_sec': set.durationSeconds,
          });
    }
  }

  Future<List<WorkoutExercise>> fetchWorkoutExercises(String workoutPlanId) async {
    try {
      // Try to fetch from workout_exercises table (new structure)
      final exercisesResponse = await _client
          .from('workout_exercises')
          .select('*')
          .eq('workout_id', workoutPlanId)
          .order('order_index');

      final List exercisesData = exercisesResponse;
      final exercises = <WorkoutExercise>[];

      for (final exData in exercisesData) {
        final exMap = exData as Map<String, dynamic>;
        final workoutExerciseId = exMap['id'] as String;
        
        // Fetch sets for this exercise
        final setsResponse = await _client
            .from('workout_sets')
            .select('*')
            .eq('workout_exercise_id', workoutExerciseId)
            .order('order_index');

        final List setsData = setsResponse;
        
        // Convert workout_sets to ExerciseSet objects
        final exerciseSets = setsData.map((setData) {
          final setMap = setData as Map<String, dynamic>;
          return ExerciseSet(
            id: setMap['id'] as String? ?? '',
            workoutExerciseId: workoutExerciseId,
            reps: setMap['target_reps'] as int?,
            weight: (setMap['target_weight'] as num?)?.toDouble(),
            durationSeconds: setMap['target_time_sec'] as int?,
            isCompleted: false,
          );
        }).toList();
        
        // Create WorkoutExercise from workout_exercises data
        final workoutExercise = WorkoutExercise(
          id: workoutExerciseId,
          workoutPlanId: workoutPlanId,
          exerciseId: exMap['exercise_id'] as String? ?? '',
          exerciseName: exMap['exercise_name'] as String? ?? 'Unknown Exercise',
          orderIndex: exMap['order_index'] as int? ?? 0,
          sets: exerciseSets,
          restSeconds: exMap['rest_seconds'] as int? ?? 60,
          notes: exMap['notes'] as String?,
        );
        
        exercises.add(workoutExercise);
      }

      // If we got results, return them
      if (exercises.isNotEmpty) {
        return exercises;
      }
    } catch (e) {
      // Table doesn't exist or error - fall back to old method
      // This handles backward compatibility
    }

    // Fallback: Fetch from workout_sets directly (old structure, before migration)
    final response = await _client
        .from('workout_sets')
        .select('*')
        .eq('workout_id', workoutPlanId)
        .order('order_index');

    final List setsData = response;
    
    // Group sets by exercise_id and order_index to form WorkoutExercise objects
    final Map<String, List<Map<String, dynamic>>> exerciseGroups = {};
    
    for (final setData in setsData) {
      final setMap = setData as Map<String, dynamic>;
      final exerciseId = setMap['exercise_id'] as String;
      final orderIndex = setMap['order_index'] as int? ?? 0;
      final key = '$exerciseId|$orderIndex';
      
      if (!exerciseGroups.containsKey(key)) {
        exerciseGroups[key] = [];
      }
      exerciseGroups[key]!.add(setMap);
    }

    final exercises = <WorkoutExercise>[];
    
    // Fetch exercise names from exercises table
    final exerciseIds = exerciseGroups.keys.map((k) => k.split('|')[0]).toSet().toList();
    final exercisesMap = <String, Map<String, dynamic>>{};
    
    if (exerciseIds.isNotEmpty) {
      dynamic qb = _client.from('exercises').select('*');
      if (exerciseIds.length == 1) {
        qb = qb.eq('id', exerciseIds.first);
      } else {
        final orExpr = exerciseIds.map((id) => 'id.eq.$id').join(',');
        qb = qb.or(orExpr);
      }
      final exercisesResponse = await qb;
      
      for (final ex in exercisesResponse) {
        final exMap = ex as Map<String, dynamic>;
        exercisesMap[exMap['id'] as String] = exMap;
      }
    }

    for (final entry in exerciseGroups.entries) {
      final parts = entry.key.split('|');
      final exerciseId = parts[0];
      final orderIndex = int.parse(parts[1]);
      final sets = entry.value;
      
      // Get exercise name
      final exerciseInfo = exercisesMap[exerciseId];
      final exerciseName = exerciseInfo?['name'] as String? ?? 'Unknown Exercise';
      
      // Convert workout_sets to ExerciseSet objects
      final exerciseSets = sets.map((setMap) {
        return ExerciseSet(
          id: setMap['id'] as String? ?? '',
          workoutExerciseId: exerciseId, // Using exercise_id as workoutExerciseId
          reps: setMap['target_reps'] as int?,
          weight: (setMap['target_weight'] as num?)?.toDouble(),
          durationSeconds: setMap['target_time_sec'] as int?,
          isCompleted: false,
        );
      }).toList();
      
      // Create WorkoutExercise
      final workoutExercise = WorkoutExercise(
        id: exerciseId, // Using exercise_id as the WorkoutExercise id
        workoutPlanId: workoutPlanId,
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        orderIndex: orderIndex,
        sets: exerciseSets,
        restSeconds: 60, // Default rest time
        notes: null,
      );
      
      exercises.add(workoutExercise);
    }

    return exercises;
  }

  Future<List<ExerciseSet>> fetchExerciseSets(String workoutExerciseId) async {
    // This method is now integrated into fetchWorkoutExercises
    // Keeping it for backward compatibility but it won't be used directly
    final response = await _client
        .from('workout_sets')
        .select('*')
        .eq('exercise_id', workoutExerciseId)
        .order('order_index');

    final List setsData = response;
    return setsData.map((setData) {
      final setMap = setData as Map<String, dynamic>;
      return ExerciseSet(
        id: setMap['id'] as String? ?? '',
        workoutExerciseId: workoutExerciseId,
        reps: setMap['target_reps'] as int?,
        weight: (setMap['target_weight'] as num?)?.toDouble(),
        durationSeconds: setMap['target_time_sec'] as int?,
        isCompleted: false,
      );
    }).toList();
  }
}

