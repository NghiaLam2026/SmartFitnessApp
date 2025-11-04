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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout saved successfully!')),
        );
        // Refresh the workout library
        ref.invalidate(userWorkoutPlansProvider);
        context.pop();
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
                  Text(
                    'Generated Workout Plans',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                return Padding(
                  padding: EdgeInsets.only(bottom: index < _generatedPlans!.length - 1 ? 16 : 0),
                  child: WorkoutOptionCard(
                    plan: plan,
                    index: index,
                    onSelect: () => _saveWorkoutPlan(plan),
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

class WorkoutOptionCard extends StatelessWidget {
  const WorkoutOptionCard({
    super.key,
    required this.plan,
    required this.index,
    required this.onSelect,
  });

  final WorkoutPlan plan;
  final int index;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exerciseCount = plan.exercises.length;
    final totalSets = plan.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets.length,
    );

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          // Show workout details before saving
          _showWorkoutDetails(context, plan, onSelect);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              // Header with option number
                Row(
                  children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
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
              const SizedBox(height: 16),

              // Stats
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _StatItem(
                    icon: Icons.fitness_center,
                    label: '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'}',
                  ),
                  _StatItem(
                    icon: Icons.repeat,
                    label: '$totalSets sets',
                  ),
                  _StatItem(
                    icon: Icons.timer_outlined,
                    label: '${_estimateDuration(totalSets)} min',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _showWorkoutDetails(context, plan, onSelect),
                  icon: const Icon(Icons.add_rounded),
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

  int _estimateDuration(int totalSets) {
    // Rough estimate: 2 minutes per set (including rest)
    return (totalSets * 2).clamp(15, 120);
  }

  void _showWorkoutDetails(BuildContext context, WorkoutPlan plan, VoidCallback onSave) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
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
              // Exercises list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: plan.exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = plan.exercises[index];
                    return _ExerciseDetailItem(
                      exercise: exercise,
                      index: index,
                    );
                  },
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
      if (set.durationSeconds != null) {
        return '${set.durationSeconds}s';
      } else if (set.reps != null) {
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