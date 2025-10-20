import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/models.dart';

class WorkoutRepository {
  WorkoutRepository();

  Future<String> _ensureExercise(String name, {String? muscle, String? equipment}) async {
    final String lower = name.toLowerCase();
    final existing = await supabase
        .from('exercises')
        .select('id')
        .ilike('name', lower)
        .maybeSingle();
    if (existing != null && existing['id'] != null) {
      return existing['id'] as String;
    }
    final inserted = await supabase
        .from('exercises')
        .insert(<String, dynamic>{
          'name': name,
          'muscle': muscle,
          'equipment': equipment,
        })
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  Future<String> createWorkout({required String title, DateTime? scheduledAt, String? planId}) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    final res = await supabase
        .from('workouts')
        .insert(<String, dynamic>{
          'user_id': user.id,
          'title': title,
          'scheduled_at': scheduledAt?.toIso8601String(),
          'status': 'planned',
          if (planId != null) 'plan_id': planId,
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  Future<void> addWorkoutSets(String workoutId, List<SessionExercise> items) async {
    int order = 1;
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
    for (final item in items) {
      final String exId = await _ensureExercise(
        item.exercise.name,
        muscle: (item.exercise.primaryMuscles.isNotEmpty) ? item.exercise.primaryMuscles.first : null,
        equipment: describeEnum(item.exercise.equipment),
      );
      final int avgReps = ((item.prescription.repsMin + item.prescription.repsMax) / 2).round();
      rows.add(<String, dynamic>{
        'workout_id': workoutId,
        'exercise_id': exId,
        'order_index': order++,
        'target_reps': avgReps,
        'target_weight': item.prescription.targetWeightKg,
        'target_time_sec': null,
        'target_rpe': item.prescription.targetRpe,
      });
    }
    if (rows.isNotEmpty) {
      await supabase.from('workout_sets').insert(rows);
    }
  }

  Future<String> createPlan({required String name, required String goalType}) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    final res = await supabase
        .from('plans')
        .insert(<String, dynamic>{
          'user_id': user.id,
          'goal_type': goalType,
          'status': 'active',
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  Future<String> savePlan(WorkoutPlan plan) async {
    final String planId = await createPlan(name: plan.name, goalType: _goalToDb(plan.goal));
    for (final session in plan.sessions) {
      final String workoutId = await createWorkout(title: session.title, planId: planId);
      await addWorkoutSets(workoutId, session.exercises);
    }
    return planId;
  }

  Future<void> deleteWorkout(String workoutId) async {
    await supabase.from('workouts').delete().eq('id', workoutId);
  }

  String _goalToDb(WorkoutGoal g) {
    switch (g) {
      case WorkoutGoal.generalFitness:
        return 'generalFitness';
      case WorkoutGoal.strength:
        return 'strength';
      case WorkoutGoal.conditioning:
        return 'conditioning';
    }
  }
}

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository();
});


