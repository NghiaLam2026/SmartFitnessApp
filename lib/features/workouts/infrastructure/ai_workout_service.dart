import 'package:dio/dio.dart';
import '../domain/workout_models.dart';
import '../../../features/exercises/domain/exercise_models.dart';

/// Service for interacting with AI to generate workout plans
abstract class AIWorkoutService {
  Future<AIGeneratedWorkout> generateWorkout(String userMessage, List<Exercise> availableExercises);
}

class GeminiAIWorkoutService implements AIWorkoutService {
  final Dio _dio;
  final String apiKey;
  final String baseUrl;

  GeminiAIWorkoutService({
    required this.apiKey,
    required this.baseUrl,
  }) : _dio = Dio();

  @override
  Future<AIGeneratedWorkout> generateWorkout(
    String userMessage,
    List<Exercise> availableExercises,
  ) async {
    try {
      // Format exercises for backend
      final exercisesData = availableExercises
          .take(100) // Limit to 100 exercises to avoid token limits
          .map((e) => {
                'id': e.id,
                'name': e.name,
                'muscle': e.muscle,
                'equipment': e.equipment ?? 'none',
              })
          .toList();

      print('🚀 Sending request to: $baseUrl/generate-workout');
      print('📝 Message: $userMessage');
      print('💪 Exercises count: ${exercisesData.length}');

      final response = await _dio.post(
        '$baseUrl/generate-workout',
        data: {
          'message': userMessage,
          'exercises': exercisesData,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 60), // Increase timeout for AI generation
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      print('✅ Response status: ${response.statusCode}');
      print('📦 Response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final message = data['message'] as String? ?? 'Generated workout plans';
        
        // Try to parse multiple workouts first
        final workoutsData = data['workouts'] as List?;
        if (workoutsData != null && workoutsData.isNotEmpty) {
          print('🎯 Found ${workoutsData.length} workouts');
          final plans = workoutsData
              .map((workoutData) => _parseAIPlan(workoutData as Map<String, dynamic>))
              .toList();
          return AIGeneratedWorkout(message: message, plans: plans);
        }
        
        // Fallback to single plan for backward compatibility
        final planData = data['plan'] as Map<String, dynamic>?;
        if (planData != null) {
          final plan = _parseAIPlan(planData);
          return AIGeneratedWorkout(message: message, plans: [plan]);
        }

        print('⚠️ No workouts found in response');
        return AIGeneratedWorkout(
          message: 'No workouts generated. Please try again with different specifications.',
        );
      }

      throw Exception('Failed to generate workout: HTTP ${response.statusCode}');
    } on DioException catch (e) {
      // Handle Dio-specific errors
      String errorMessage = 'Failed to generate workout. ';
      
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage += 'Request timed out. Please check your connection and try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage += 'Could not connect to server. Please ensure the backend is running at $baseUrl';
      } else if (e.response != null) {
        errorMessage += 'Server error (${e.response?.statusCode}): ${e.response?.data}';
      } else {
        errorMessage += 'Network error: ${e.message}';
      }
      
      print('❌ Dio Error: ${e.type}');
      print('❌ Error message: ${e.message}');
      print('❌ Response: ${e.response?.data}');
      
      return AIGeneratedWorkout(message: errorMessage);
    } catch (e, stackTrace) {
      print('❌ Unexpected error: $e');
      print('❌ Stack trace: $stackTrace');
      
      return AIGeneratedWorkout(
        message: 'Failed to generate workout: ${e.toString()}. Please try again or create a workout manually.',
      );
    }
  }


  WorkoutPlan _parseAIPlan(Map<String, dynamic> planData) {
    try {
      final exercisesData = planData['exercises'] as List?;
      final exercises = <WorkoutExercise>[];

      if (exercisesData == null || exercisesData.isEmpty) {
        print('⚠️ No exercises found in workout plan');
        return WorkoutPlan(
          id: '',
          title: planData['title'] as String? ?? 'AI Generated Workout',
          description: planData['description'] as String?,
          userId: '',
          createdAt: DateTime.now(),
          isAIGenerated: true,
          exercises: [],
        );
      }

      for (int i = 0; i < exercisesData.length; i++) {
        try {
          final exData = exercisesData[i] as Map<String, dynamic>;
          final setsData = exData['sets'] as List?;
          
          if (setsData == null || setsData.isEmpty) {
            print('⚠️ Exercise ${exData['exerciseName']} has no sets, skipping');
            continue;
          }

          final sets = setsData
              .map((s) {
                final setMap = s as Map<String, dynamic>;
                    return ExerciseSet(
                      id: '', // Will be generated by database
                      workoutExerciseId: '',
                      reps: setMap['reps'] as int?,
                      weight: (setMap['weight'] as num?)?.toDouble(),
                    );
              })
              .toList();

          final exerciseId = exData['exerciseId'] as String? ?? '';
          final exerciseName = exData['exerciseName'] as String? ?? 'Exercise';
          final orderIndex = exData['orderIndex'] as int? ?? i;
          final restSeconds = exData['restSeconds'] as int? ?? 60;

          exercises.add(WorkoutExercise(
            id: '', // Will be generated by database
            workoutPlanId: '',
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            orderIndex: orderIndex,
            sets: sets,
            restSeconds: restSeconds,
          ));
        } catch (e) {
          print('⚠️ Error parsing exercise at index $i: $e');
          // Continue with next exercise
          continue;
        }
      }

      return WorkoutPlan(
        id: '', // Will be generated
        title: planData['title'] as String? ?? 'AI Generated Workout',
        description: planData['description'] as String?,
        userId: '', // Will be set by the repository
        createdAt: DateTime.now(),
        isAIGenerated: true,
        exercises: exercises,
      );
    } catch (e, stackTrace) {
      print('❌ Error parsing workout plan: $e');
      print('❌ Stack trace: $stackTrace');
      print('❌ Plan data: $planData');
      rethrow;
    }
  }
}

/// Local mock service for development/testing
class MockAIWorkoutService implements AIWorkoutService {
  @override
  Future<AIGeneratedWorkout> generateWorkout(
    String userMessage,
    List<Exercise> availableExercises,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    if (availableExercises.isEmpty) {
      return const AIGeneratedWorkout(
        message: 'No exercises available. Please ensure exercises are loaded.',
      );
    }

    // Generate 3 different mock workout plans
    final plans = <WorkoutPlan>[];
    
    for (int planIndex = 0; planIndex < 3; planIndex++) {
      final exerciseCount = 5 + planIndex; // Vary exercise count (5, 6, 7)
      final startIndex = planIndex * 5; // Start from different positions
      
      final exercises = availableExercises
          .skip(startIndex)
          .take(exerciseCount)
          .toList();
      
      if (exercises.isEmpty) {
        // If we run out of exercises, wrap around
        exercises.addAll(availableExercises.take(exerciseCount));
      }

      final workoutExercises = exercises.asMap().entries.map((entry) {
        final exercise = entry.value;
        final setsCount = 3 + (planIndex % 2); // Vary sets (3 or 4)
        final reps = 10 + (planIndex * 2); // Vary reps (10, 12, 14)
        
        return WorkoutExercise(
          id: '',
          workoutPlanId: '',
          exerciseId: exercise.id,
          exerciseName: exercise.name,
          orderIndex: entry.key,
          sets: List.generate(
            setsCount,
            (i) => ExerciseSet(
              id: '',
              workoutExerciseId: '',
              reps: reps,
              weight: null,
            ),
          ),
          restSeconds: 60 + (planIndex * 15), // Vary rest (60, 75, 90)
        );
      }).toList();

      final plan = WorkoutPlan(
        id: '',
        title: _generateWorkoutTitle(planIndex, userMessage),
        description: _generateWorkoutDescription(planIndex, userMessage),
        userId: '',
        createdAt: DateTime.now(),
        isAIGenerated: true,
        exercises: workoutExercises,
      );
      
      plans.add(plan);
    }

    return AIGeneratedWorkout(
      message: 'I\'ve created 3 personalized workout plans based on your request!',
      plans: plans,
    );
  }

  String _generateWorkoutTitle(int index, String userMessage) {
    final titles = [
      'Strength Focus Workout',
      'Balanced Training Session',
      'Endurance Builder',
    ];
    
    if (index < titles.length) {
      return titles[index];
    }
    
    // Fallback: extract keywords from user message
    final lowerMessage = userMessage.toLowerCase();
    if (lowerMessage.contains('strength') || lowerMessage.contains('muscle')) {
      return 'Strength Training Plan';
    } else if (lowerMessage.contains('cardio') || lowerMessage.contains('endurance')) {
      return 'Cardio Workout Plan';
    } else if (lowerMessage.contains('full') || lowerMessage.contains('body')) {
      return 'Full Body Workout';
    }
    
    return 'Workout Plan ${index + 1}';
  }

  String _generateWorkoutDescription(int index, String userMessage) {
    final descriptions = [
      'A focused strength training session designed to build muscle and power.',
      'A well-rounded workout that balances strength, endurance, and flexibility.',
      'An endurance-focused session to improve cardiovascular fitness and stamina.',
    ];
    
    if (index < descriptions.length) {
      return '${descriptions[index]} Based on: $userMessage';
    }
    
    return 'Generated based on your request: $userMessage';
  }
}

