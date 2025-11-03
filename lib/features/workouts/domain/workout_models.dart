import 'package:flutter/foundation.dart';

/// Represents a workout plan containing multiple exercises
@immutable
class WorkoutPlan {
  final String id;
  final String title;
  final String? description;
  final String userId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isAIGenerated;
  final List<WorkoutExercise> exercises;

  const WorkoutPlan({
    required this.id,
    required this.title,
    this.description,
    required this.userId,
    required this.createdAt,
    this.updatedAt,
    this.isAIGenerated = false,
    this.exercises = const [],
  });

  factory WorkoutPlan.fromMap(Map<String, dynamic> map, List<WorkoutExercise> exercises) {
    return WorkoutPlan(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      userId: map['user_id'] as String? ?? '',
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      isAIGenerated: (map['is_ai_generated'] as bool?) ?? false,
      exercises: exercises,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_ai_generated': isAIGenerated,
    };
  }
}

/// Represents an exercise within a workout plan with its sets configuration
@immutable
class WorkoutExercise {
  final String id;
  final String workoutPlanId;
  final String exerciseId; // Reference to exercises table
  final String exerciseName; // Denormalized for quick access
  final int orderIndex;
  final List<ExerciseSet> sets;
  final int restSeconds;
  final String? notes;

  const WorkoutExercise({
    required this.id,
    required this.workoutPlanId,
    required this.exerciseId,
    required this.exerciseName,
    required this.orderIndex,
    this.sets = const [],
    this.restSeconds = 60,
    this.notes,
  });

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    return WorkoutExercise(
      id: map['id'] as String? ?? '',
      workoutPlanId: map['workout_plan_id'] as String? ?? '',
      exerciseId: map['exercise_id'] as String? ?? '',
      exerciseName: map['exercise_name'] as String? ?? '',
      orderIndex: map['order_index'] as int? ?? 0,
      restSeconds: map['rest_seconds'] as int? ?? 60,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workout_plan_id': workoutPlanId,
      'exercise_id': exerciseId,
      'exercise_name': exerciseName,
      'order_index': orderIndex,
      'rest_seconds': restSeconds,
      'notes': notes,
    };
  }

  WorkoutExercise copyWith({
    String? id,
    String? workoutPlanId,
    String? exerciseId,
    String? exerciseName,
    int? orderIndex,
    List<ExerciseSet>? sets,
    int? restSeconds,
    String? notes,
  }) {
    return WorkoutExercise(
      id: id ?? this.id,
      workoutPlanId: workoutPlanId ?? this.workoutPlanId,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      orderIndex: orderIndex ?? this.orderIndex,
      sets: sets ?? this.sets,
      restSeconds: restSeconds ?? this.restSeconds,
      notes: notes ?? this.notes,
    );
  }
}

/// Represents a single set within an exercise
@immutable
class ExerciseSet {
  final String id;
  final String workoutExerciseId;
  final int? reps;
  final double? weight;
  final int? durationSeconds; // For time-based exercises (planks, etc.)
  final bool isCompleted;

  const ExerciseSet({
    required this.id,
    required this.workoutExerciseId,
    this.reps,
    this.weight,
    this.durationSeconds,
    this.isCompleted = false,
  });

  factory ExerciseSet.fromMap(Map<String, dynamic> map) {
    return ExerciseSet(
      id: map['id'] as String? ?? '',
      workoutExerciseId: map['workout_exercise_id'] as String? ?? '',
      reps: map['reps'] as int?,
      weight: map['weight'] as double?,
      durationSeconds: map['duration_seconds'] as int?,
      isCompleted: (map['is_completed'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workout_exercise_id': workoutExerciseId,
      'reps': reps,
      'weight': weight,
      'duration_seconds': durationSeconds,
      'is_completed': isCompleted,
    };
  }

  ExerciseSet copyWith({
    String? id,
    String? workoutExerciseId,
    int? reps,
    double? weight,
    int? durationSeconds,
    bool? isCompleted,
  }) {
    return ExerciseSet(
      id: id ?? this.id,
      workoutExerciseId: workoutExerciseId ?? this.workoutExerciseId,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// Result of an AI-generated workout plan
@immutable
class AIGeneratedWorkout {
  final String message;
  final WorkoutPlan? plan;

  const AIGeneratedWorkout({
    required this.message,
    this.plan,
  });
}

