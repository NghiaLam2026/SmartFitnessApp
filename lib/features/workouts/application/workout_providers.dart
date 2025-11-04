import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/workout_models.dart';
import '../infrastructure/workout_repository.dart';
import '../infrastructure/ai_workout_service.dart';
import '../../../core/supabase/supabase_client.dart';

// Repository providers
final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return SupabaseWorkoutRepository();
});

final aiWorkoutServiceProvider = Provider<AIWorkoutService>((ref) {
  // Use mock service for now - replace with real service when backend is ready
  return MockAIWorkoutService();
  // return GeminiAIWorkoutService(
  //   apiKey: 'YOUR_GEMINI_API_KEY',
  //   baseUrl: 'YOUR_NODE_BACKEND_URL',
  // );
});

// User workout plans provider
final userWorkoutPlansProvider = FutureProvider.autoDispose<List<WorkoutPlan>>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final repository = ref.read(workoutRepositoryProvider);
  return repository.fetchUserWorkoutPlans(user.id);
});

// Individual workout plan provider
final workoutPlanProvider = FutureProvider.autoDispose.family<WorkoutPlan?, String>((ref, id) async {
  final repository = ref.read(workoutRepositoryProvider);
  return repository.fetchWorkoutPlanById(id);
});

// Workout builder state (for manual creation)
final workoutBuilderProvider = StateNotifierProvider<WorkoutBuilderNotifier, WorkoutPlan?>((ref) {
  return WorkoutBuilderNotifier();
});

class WorkoutBuilderNotifier extends StateNotifier<WorkoutPlan?> {
  WorkoutBuilderNotifier() : super(null);

  void initializeBuilder() {
    final user = supabase.auth.currentUser;
    state = WorkoutPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Temporary ID
      title: '',
      userId: user?.id ?? '',
      createdAt: DateTime.now(),
      isAIGenerated: false,
      exercises: [],
    );
  }

  void updateTitle(String title) {
    if (state == null) return;
    state = state!.copyWith(title: title);
  }

  void updateDescription(String description) {
    if (state == null) return;
    state = state!.copyWith(description: description);
  }

  void addExercise(WorkoutExercise exercise) {
    if (state == null) return;
    state = state!.copyWith(
      exercises: [...state!.exercises, exercise],
    );
  }

  void removeExercise(WorkoutExercise exercise) {
    if (state == null) return;
    state = state!.copyWith(
      exercises: state!.exercises.where((e) => e.id != exercise.id).toList(),
    );
  }

  void updateExercise(WorkoutExercise exercise) {
    if (state == null) return;
    final exercises = List<WorkoutExercise>.from(state!.exercises);
    final index = exercises.indexWhere((e) => e.id == exercise.id);
    if (index >= 0) {
      exercises[index] = exercise;
    }
    state = state!.copyWith(exercises: exercises);
  }

  void loadWorkout(WorkoutPlan plan) {
    state = plan;
  }

  void clear() {
    state = null;
  }
}

/// Extension to add copyWith method to WorkoutPlan
extension WorkoutPlanCopyWith on WorkoutPlan {
  WorkoutPlan copyWith({
    String? id,
    String? title,
    String? description,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAIGenerated,
    List<WorkoutExercise>? exercises,
  }) {
    return WorkoutPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAIGenerated: isAIGenerated ?? this.isAIGenerated,
      exercises: exercises ?? this.exercises,
    );
  }
}

