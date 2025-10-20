import 'package:flutter/foundation.dart';

/// Difficulty tiers used throughout the workout feature.
enum WorkoutDifficulty { easy, medium, hard }

/// High-level workout goal to guide generation logic.
enum WorkoutGoal { generalFitness, strength, conditioning }

/// Equipment options supported for generation and filtering.
enum EquipmentType { none, bands, dumbbells, barbell, machines }

@immutable
class Exercise {
  final String id;
  final String name;
  final List<String> primaryMuscles;
  final EquipmentType equipment;
  final bool unilateral;

  const Exercise({
    required this.id,
    required this.name,
    required this.primaryMuscles,
    required this.equipment,
    this.unilateral = false,
  });
}

/// A prescription for a single exercise within a session.
@immutable
class SetPrescription {
  final int sets;
  final int repsMin;
  final int repsMax;
  final int restSeconds;
  final double? targetRpe; // 1-10 scale (optional for custom builder)
  final double? targetWeightKg; // optional weight target in kg

  const SetPrescription({
    required this.sets,
    required this.repsMin,
    required this.repsMax,
    required this.restSeconds,
    this.targetRpe,
    this.targetWeightKg,
  });
}

@immutable
class SessionExercise {
  final Exercise exercise;
  final SetPrescription prescription;

  const SessionExercise({
    required this.exercise,
    required this.prescription,
  });
}

@immutable
class WorkoutSession {
  final String id;
  final String title;
  final Duration estimatedDuration;
  final WorkoutDifficulty difficulty;
  final List<SessionExercise> exercises;

  const WorkoutSession({
    required this.id,
    required this.title,
    required this.estimatedDuration,
    required this.difficulty,
    required this.exercises,
  });
}

@immutable
class WorkoutPlan {
  final String id;
  final String name;
  final WorkoutGoal goal;
  final int weeks;
  final List<WorkoutSession> sessions; // flattened for MVP

  const WorkoutPlan({
    required this.id,
    required this.name,
    required this.goal,
    required this.weeks,
    required this.sessions,
  });
}


