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

    // Insert workout plan
    final response = await _client
        .from('workout_plans')
        .insert({
          'id': plan.id,
          'title': plan.title,
          'description': plan.description,
          'user_id': user.id,
          'is_ai_generated': plan.isAIGenerated,
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
    final response = await _client
        .from('workout_plans')
        .select('*')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;

    // Fetch exercises for this workout
    final exercises = await fetchWorkoutExercises(id);

    return WorkoutPlan.fromMap(response, exercises);
  }

  @override
  Future<List<WorkoutPlan>> fetchUserWorkoutPlans(String userId) async {
    final response = await _client
        .from('workout_plans')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final List plans = response;

    // Fetch exercises for each plan
    final workoutPlans = <WorkoutPlan>[];
    for (final planData in plans) {
      final plan = WorkoutPlan.fromMap(
        planData as Map<String, dynamic>,
        await fetchWorkoutExercises(planData['id'] as String),
      );
      workoutPlans.add(plan);
    }

    return workoutPlans;
  }

  @override
  Future<void> updateWorkoutPlan(WorkoutPlan plan) async {
    await _client
        .from('workout_plans')
        .update({
          'title': plan.title,
          'description': plan.description,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', plan.id);
  }

  @override
  Future<void> deleteWorkoutPlan(String id) async {
    // Delete exercises and sets first (should be handled by database cascade, but being explicit)
    final exercises = await fetchWorkoutExercises(id);
    for (final exercise in exercises) {
      await _client
          .from('exercise_sets')
          .delete()
          .eq('workout_exercise_id', exercise.id);
    }

    await _client
        .from('workout_exercises')
        .delete()
        .eq('workout_plan_id', id);

    await _client.from('workout_plans').delete().eq('id', id);
  }

  @override
  Future<void> addExerciseToWorkout(String workoutPlanId, WorkoutExercise exercise) async {
    await _addExerciseToWorkout(workoutPlanId, exercise);
  }

  Future<void> _addExerciseToWorkout(String workoutPlanId, WorkoutExercise exercise) async {
    // Insert workout exercise
    final exerciseResponse = await _client
        .from('workout_exercises')
        .insert({
          'id': exercise.id,
          'workout_plan_id': workoutPlanId,
          'exercise_id': exercise.exerciseId,
          'exercise_name': exercise.exerciseName,
          'order_index': exercise.orderIndex,
          'rest_seconds': exercise.restSeconds,
          'notes': exercise.notes,
        })
        .select('id')
        .single();

    final exerciseId = exerciseResponse['id'] as String;

    // Insert sets
    for (int i = 0; i < exercise.sets.length; i++) {
      final set = exercise.sets[i];
      await _client
          .from('exercise_sets')
          .insert({
            'workout_exercise_id': exerciseId,
            'reps': set.reps,
            'weight': set.weight,
            'duration_seconds': set.durationSeconds,
            'set_number': i + 1,
            'is_completed': set.isCompleted,
          });
    }
  }

  @override
  Future<void> removeExerciseFromWorkout(String workoutExerciseId) async {
    // Delete sets first
    await _client
        .from('exercise_sets')
        .delete()
        .eq('workout_exercise_id', workoutExerciseId);

    // Delete exercise
    await _client
        .from('workout_exercises')
        .delete()
        .eq('id', workoutExerciseId);
  }

  @override
  Future<void> updateExerciseInWorkout(WorkoutExercise exercise) async {
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
        .from('exercise_sets')
        .delete()
        .eq('workout_exercise_id', exercise.id);

    for (int i = 0; i < exercise.sets.length; i++) {
      final set = exercise.sets[i];
      await _client
          .from('exercise_sets')
          .insert({
            'workout_exercise_id': exercise.id,
            'reps': set.reps,
            'weight': set.weight,
            'duration_seconds': set.durationSeconds,
            'set_number': i + 1,
            'is_completed': set.isCompleted,
          });
    }
  }

  Future<List<WorkoutExercise>> fetchWorkoutExercises(String workoutPlanId) async {
    final response = await _client
        .from('workout_exercises')
        .select('*')
        .eq('workout_plan_id', workoutPlanId)
        .order('order_index');

    final List exercisesData = response;
    final exercises = <WorkoutExercise>[];

    for (final exData in exercisesData) {
      final exerciseId = exData['id'] as String;
      
      // Fetch sets for this exercise
      final sets = await fetchExerciseSets(exerciseId);

      final exercise = WorkoutExercise.fromMap(exData as Map<String, dynamic>);
      exercises.add(exercise.copyWith(sets: sets));
    }

    return exercises;
  }

  Future<List<ExerciseSet>> fetchExerciseSets(String workoutExerciseId) async {
    final response = await _client
        .from('exercise_sets')
        .select('*')
        .eq('workout_exercise_id', workoutExerciseId)
        .order('set_number');

    final List setsData = response;
    return setsData
        .map((setData) => ExerciseSet.fromMap(setData as Map<String, dynamic>))
        .toList();
  }
}

