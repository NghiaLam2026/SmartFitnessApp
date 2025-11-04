import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../exercises/infrastructure/exercises_repository.dart';
import '../application/workout_providers.dart';
import '../domain/workout_models.dart';

final uuid = Uuid();

class AIWorkoutPage extends ConsumerStatefulWidget {
  const AIWorkoutPage({super.key});

  @override
  ConsumerState<AIWorkoutPage> createState() => _AIWorkoutPageState();
}

class _AIWorkoutPageState extends ConsumerState<AIWorkoutPage> {
  final _specificationController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isGenerating = false;
  List<WorkoutPlan>? _generatedPlans;
  String? _errorMessage;
  final Set<String> _savedWorkoutTitles = {}; // Track which workouts have been saved

  @override
  void dispose() {
    _specificationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _generateWorkouts() async {
    final specification = _specificationController.text.trim();
    if (specification.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your workout specifications')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedPlans = null;
      _errorMessage = null;
    });

    try {
      // Load available exercises
      final exercisesRepo = SupabaseExercisesRepository();
      final exercises = await exercisesRepo.fetchExercises(limit: 100);

      if (exercises.isEmpty) {
        setState(() {
          _isGenerating = false;
          _errorMessage = 'No exercises available. Please ensure exercises are loaded.';
        });
        return;
      }

      // Generate workouts using AI
      final aiService = ref.read(aiWorkoutServiceProvider);
      final result = await aiService.generateWorkout(specification, exercises);

      if (!mounted) return;

      if (result.plans.isEmpty) {
        setState(() {
          _isGenerating = false;
          _errorMessage = result.message;
        });
      } else {
        setState(() {
          _isGenerating = false;
          _generatedPlans = result.plans;
          _errorMessage = null;
        });
        // Scroll to results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
    } catch (e) {
      if (!mounted) return;
    setState(() {
        _isGenerating = false;
        _errorMessage = 'Failed to generate workouts: $e';
      });
    }
  }

  Future<void> _saveWorkoutPlan(WorkoutPlan plan) async {
    try {
      final repository = ref.read(workoutRepositoryProvider);
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create final plan with proper IDs
      final finalPlan = WorkoutPlan(
        id: uuid.v4(),
        title: plan.title,
        description: plan.description,
        userId: user.id,
        createdAt: DateTime.now(),
        isAIGenerated: true,
        exercises: plan.exercises.map((ex) {
          // Generate IDs for exercises and sets
          final exerciseId = uuid.v4();
          final sets = ex.sets.map((s) => s.copyWith(
            id: uuid.v4(),
            workoutExerciseId: exerciseId,
          )).toList();

          return ex.copyWith(
            id: exerciseId,
            sets: sets,
          );
        }).toList(),
      );

      await repository.createWorkoutPlan(finalPlan);
      
      if (mounted) {
        // Mark this workout as saved
        setState(() {
          _savedWorkoutTitles.add(plan.title);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout saved successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
        // Refresh the workout library (but don't navigate away)
        ref.invalidate(userWorkoutPlansProvider);
        // Keep the generated workouts visible so user can add more
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving workout: $e')),
        );
      }
    }
  }

  void _regenerateWorkouts() {
    setState(() {
      _generatedPlans = null;
      _errorMessage = null;
      _savedWorkoutTitles.clear(); // Clear saved workouts when regenerating
    });
    _generateWorkouts();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Workout Generator'),
      ),
      body: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Generate Your Workout',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Describe your workout goals, preferences, or requirements. Our AI will generate 3 personalized workout plans for you to choose from.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Input section
            Text(
              'Workout Specifications',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _specificationController,
              decoration: InputDecoration(
                hintText: 'e.g., Upper body strength workout, 45 minutes, beginner level',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(16),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              enabled: !_isGenerating,
            ),
            const SizedBox(height: 16),

            // Generate button
            FilledButton.icon(
              onPressed: _isGenerating ? null : _generateWorkouts,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_isGenerating ? 'Generating...' : 'Generate Workout'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size.fromHeight(56),
              ),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
            padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
              child: Row(
                children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                  Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Generated workouts section
            if (_generatedPlans != null && _generatedPlans!.isNotEmpty) ...[
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Generated Workout Plans',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _regenerateWorkouts,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Regenerate'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._generatedPlans!.asMap().entries.map((entry) {
                final index = entry.key;
                final plan = entry.value;
                final isSaved = _savedWorkoutTitles.contains(plan.title);
                return Padding(
                  padding: EdgeInsets.only(bottom: index < _generatedPlans!.length - 1 ? 16 : 0),
                  child: _AIGeneratedWorkoutCard(
                    plan: plan,
                    isSaved: isSaved,
                    onTap: () {
                      // Show workout details in a modal similar to workout detail page
                      _showWorkoutPreview(context, plan, () => _saveWorkoutPlan(plan));
                    },
                    onSave: () => _saveWorkoutPlan(plan),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card widget for AI-generated workout options
/// Similar to _WorkoutPlanCard from workout_library_page.dart
class _AIGeneratedWorkoutCard extends StatelessWidget {
  const _AIGeneratedWorkoutCard({
    required this.plan,
    required this.onTap,
    required this.onSave,
    this.isSaved = false,
  });

  final WorkoutPlan plan;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exerciseCount = plan.exercises.length;
    final totalSets = plan.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets.length,
    );

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                plan.title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (plan.description != null && plan.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            plan.description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatChip(
                    icon: Icons.fitness_center,
                    label: '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'}',
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    icon: Icons.repeat,
                    label: '$totalSets sets',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: isSaved
                    ? OutlinedButton.icon(
                        onPressed: null, // Disabled
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text('Already Saved'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: () {
                          onSave();
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add to My Workouts'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
        ),
      ],
    );
  }
}

void _showWorkoutPreview(BuildContext context, WorkoutPlan plan, VoidCallback onSave) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (plan.description != null && plan.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            plan.description!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Exercises list - using the same structure as WorkoutDetailPage
            Expanded(
              child: ListView(
                controller: scrollController,
              padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Icon(Icons.fitness_center_rounded, size: 20, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      const SizedBox(width: 8),
                      Text(
                        '${plan.exercises.length} Exercises',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.repeat_rounded, size: 20, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      const SizedBox(width: 8),
                      Text(
                        '${plan.exercises.fold<int>(0, (sum, ex) => sum + ex.sets.length)} Sets',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  ...plan.exercises.asMap().entries.map((entry) {
                    final index = entry.key;
                    final exercise = entry.value;
                    return _ExerciseCard(
                      exercise: exercise,
                      exerciseNumber: index + 1,
                    );
                  }).toList(),
                ],
              ),
            ),
            // Action button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onSave();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add to My Workouts'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

class _ExerciseCard extends StatelessWidget {
  final WorkoutExercise exercise;
  final int exerciseNumber;

  const _ExerciseCard({
    required this.exercise,
    required this.exerciseNumber,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSets = exercise.sets.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            '$exerciseNumber',
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          exercise.exerciseName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$totalSets ${totalSets == 1 ? 'set' : 'sets'} • ${exercise.restSeconds}s rest',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sets',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...exercise.sets.asMap().entries.map((entry) {
                  final setIndex = entry.key;
                  final set = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                  children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                      child: Text(
                              '${setIndex + 1}',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                        ),
                      ),
                    ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              if (set.reps != null) ...[
                                _SetInfo(
                                  icon: Icons.repeat_rounded,
                                  label: '${set.reps} reps',
                                ),
                                const SizedBox(width: 16),
                              ],
                            ],
                  ),
                ),
              ],
            ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetInfo extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SetInfo({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
        ),
      ],
    );
  }
}

class _ExerciseDetailItem extends StatelessWidget {
  const _ExerciseDetailItem({required this.exercise, required this.index});

  final WorkoutExercise exercise;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setsInfo = exercise.sets.map((set) {
      if (set.reps != null) {
        return '${set.reps} reps';
      }
      return '1 set';
    }).join(' × ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          exercise.exerciseName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${exercise.sets.length} sets: $setsInfo'),
            if (exercise.restSeconds > 0)
              Text(
                '${exercise.restSeconds}s rest',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}