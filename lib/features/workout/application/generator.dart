import 'dart:math';
import '../domain/models.dart';
import '../domain/presets.dart';

class WorkoutGeneratorInput {
  final WorkoutGoal goal;
  final WorkoutDifficulty difficulty;
  final int daysPerWeek;
  final int minutesPerSession;
  final List<EquipmentType> equipment;

  const WorkoutGeneratorInput({
    required this.goal,
    required this.difficulty,
    required this.daysPerWeek,
    required this.minutesPerSession,
    required this.equipment,
  });
}

class WorkoutGenerator {
  static WorkoutPlan generatePlan(WorkoutGeneratorInput input) {
    final List<WorkoutSession> sessions = <WorkoutSession>[];
    for (int i = 0; i < input.daysPerWeek; i++) {
      sessions.add(_generateSession(i + 1, input));
    }
    return WorkoutPlan(
      id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      name: _planName(input),
      goal: input.goal,
      weeks: 4,
      sessions: sessions,
    );
  }

  static WorkoutSession _generateSession(int index, WorkoutGeneratorInput input) {
    final List<Exercise> pool = ExerciseLibrary.all.where((e) => input.equipment.contains(e.equipment) || e.equipment == EquipmentType.none).toList();
    final Random rng = Random(index);

    Exercise pick(String muscle) {
      final List<Exercise> filtered = pool.where((e) => e.primaryMuscles.contains(muscle)).toList();
      if (filtered.isEmpty) return pool[rng.nextInt(pool.length)];
      return filtered[rng.nextInt(filtered.length)];
    }

    SetPrescription byTier() {
      switch (input.difficulty) {
        case WorkoutDifficulty.easy:
          return TierDefaults.easy();
        case WorkoutDifficulty.medium:
          return TierDefaults.medium();
        case WorkoutDifficulty.hard:
          return TierDefaults.hard();
      }
    }

    final List<SessionExercise> exercises = <SessionExercise>[
      SessionExercise(exercise: pick('quads'), prescription: byTier()),
      SessionExercise(exercise: pick('chest'), prescription: byTier()),
      SessionExercise(exercise: pick('hamstrings'), prescription: byTier()),
      SessionExercise(exercise: pick('lats'), prescription: byTier()),
    ];

    final Duration duration = Duration(minutes: input.minutesPerSession.clamp(15, 60));

    return WorkoutSession(
      id: 'sess_${DateTime.now().millisecondsSinceEpoch}_$index',
      title: 'Session $index',
      estimatedDuration: duration,
      difficulty: input.difficulty,
      exercises: exercises,
    );
  }

  static String _planName(WorkoutGeneratorInput input) {
    final String tier = switch (input.difficulty) {
      WorkoutDifficulty.easy => 'Easy',
      WorkoutDifficulty.medium => 'Medium',
      WorkoutDifficulty.hard => 'Hard',
    };
    final String goal = switch (input.goal) {
      WorkoutGoal.generalFitness => 'General Fitness',
      WorkoutGoal.strength => 'Strength',
      WorkoutGoal.conditioning => 'Conditioning',
    };
    return '$goal • $tier • ${input.daysPerWeek}x/week';
  }
}


