import 'models.dart';

/// Minimal exercise seed set for MVP generation and manual building.
class ExerciseLibrary {
  static const Exercise bodyweightSquat = Exercise(
    id: 'ex_bw_squat',
    name: 'Bodyweight Squat',
    primaryMuscles: ['quads', 'glutes'],
    equipment: EquipmentType.none,
  );
  static const Exercise inclinePushUp = Exercise(
    id: 'ex_incline_pushup',
    name: 'Incline Push-Up',
    primaryMuscles: ['chest', 'triceps'],
    equipment: EquipmentType.none,
  );
  static const Exercise hipHinge = Exercise(
    id: 'ex_hip_hinge',
    name: 'Hip Hinge',
    primaryMuscles: ['hamstrings', 'glutes'],
    equipment: EquipmentType.none,
  );
  static const Exercise oneArmRowBand = Exercise(
    id: 'ex_band_row',
    name: 'One-Arm Band Row',
    primaryMuscles: ['lats', 'upper back'],
    equipment: EquipmentType.bands,
    unilateral: true,
  );
  static const Exercise dbGobletSquat = Exercise(
    id: 'ex_db_goblet_squat',
    name: 'Dumbbell Goblet Squat',
    primaryMuscles: ['quads', 'glutes'],
    equipment: EquipmentType.dumbbells,
  );
  static const Exercise dbBenchPress = Exercise(
    id: 'ex_db_bench',
    name: 'Dumbbell Bench Press',
    primaryMuscles: ['chest', 'triceps'],
    equipment: EquipmentType.dumbbells,
  );
  static const Exercise dbRdl = Exercise(
    id: 'ex_db_rdl',
    name: 'Dumbbell Romanian Deadlift',
    primaryMuscles: ['hamstrings', 'glutes'],
    equipment: EquipmentType.dumbbells,
  );
  static const Exercise dbRow = Exercise(
    id: 'ex_db_row',
    name: 'One-Arm Dumbbell Row',
    primaryMuscles: ['lats', 'upper back'],
    equipment: EquipmentType.dumbbells,
    unilateral: true,
  );

  static const List<Exercise> all = <Exercise>[
    bodyweightSquat,
    inclinePushUp,
    hipHinge,
    oneArmRowBand,
    dbGobletSquat,
    dbBenchPress,
    dbRdl,
    dbRow,
  ];
}

/// Tiered set/rep/rest defaults by difficulty.
class TierDefaults {
  static SetPrescription easy({int sets = 2}) => SetPrescription(
        sets: sets,
        repsMin: 8,
        repsMax: 12,
        restSeconds: 60,
        targetRpe: 4.5,
      );

  static SetPrescription medium({int sets = 3}) => const SetPrescription(
        sets: 3,
        repsMin: 8,
        repsMax: 12,
        restSeconds: 90,
        targetRpe: 6.5,
      );

  static SetPrescription hard({int sets = 4}) => const SetPrescription(
        sets: 4,
        repsMin: 6,
        repsMax: 10,
        restSeconds: 120,
        targetRpe: 8.0,
      );
}


