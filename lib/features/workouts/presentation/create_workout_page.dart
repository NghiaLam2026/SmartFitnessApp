import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/supabase/supabase_client.dart';
import '../application/workout_providers.dart';
import '../domain/workout_models.dart';
import '../../exercises/domain/exercise_models.dart';

final uuid = Uuid();

class CreateWorkoutPage extends ConsumerStatefulWidget {
  const CreateWorkoutPage({super.key});

  @override
  ConsumerState<CreateWorkoutPage> createState() => _CreateWorkoutPageState();
}

class _CreateWorkoutPageState extends ConsumerState<CreateWorkoutPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(workoutBuilderProvider.notifier).initializeBuilder();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveWorkout() async {
    final builder = ref.read(workoutBuilderProvider.notifier);
    final plan = ref.read(workoutBuilderProvider);

    if (plan == null || plan.title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a workout title')),
      );
      return;
    }

    if (plan.exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one exercise')),
      );
      return;
    }

    try {
      final repository = ref.read(workoutRepositoryProvider);
      final user = supabase.auth.currentUser;
      
      // Create final plan with proper IDs
      final finalPlan = WorkoutPlan(
        id: uuid.v4(),
        title: plan.title,
        description: plan.description,
        userId: user?.id ?? '',
        createdAt: DateTime.now(),
        isAIGenerated: false,
        exercises: plan.exercises,
      );

      await repository.createWorkoutPlan(finalPlan);
      
      // Clear builder
      builder.clear();

      if (mounted) {
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

  void _addExercise() async {
    // Show exercise selection dialog
    final selectedExercise = await _showExerciseSelection();
    
    if (selectedExercise == null) return;

    // Show dialog to configure sets
    final configured = await _configureExercise(selectedExercise);
    if (configured != null) {
      ref.read(workoutBuilderProvider.notifier).addExercise(configured);
    }
  }
  
  Future<Exercise?> _showExerciseSelection() async {
    return showDialog<Exercise>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Exercise'),
        content: const Text('Please use the exercise library to select exercises.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<WorkoutExercise?> _configureExercise(Exercise exercise) async {
    final repsController = TextEditingController(text: '12');
    final setsController = TextEditingController(text: '3');
    final restController = TextEditingController(text: '60');

    return showDialog<WorkoutExercise>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Configure: ${exercise.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: repsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Reps per set',
                  hintText: 'e.g., 12',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: setsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of sets',
                  hintText: 'e.g., 3',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: restController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Rest (seconds)',
                  hintText: 'e.g., 60',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final reps = int.tryParse(repsController.text) ?? 12;
              final sets = int.tryParse(setsController.text) ?? 3;
              final rest = int.tryParse(restController.text) ?? 60;

              final workoutExercise = WorkoutExercise(
                id: uuid.v4(),
                workoutPlanId: '', // Will be set when saving
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                orderIndex: ref.read(workoutBuilderProvider)?.exercises.length ?? 0,
                sets: List.generate(sets, (_) => ExerciseSet(
                  id: '',
                  workoutExerciseId: '',
                  reps: reps,
                )),
                restSeconds: rest,
              );

              context.pop(workoutExercise);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(workoutBuilderProvider);

    if (plan == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    _titleController.text = plan.title;
    _descriptionController.text = plan.description ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Workout'),
        actions: [
          IconButton(
            onPressed: _saveWorkout,
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Save',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Title and description
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Workout Title',
              hintText: 'e.g., Push Day',
            ),
            onChanged: (value) {
              ref.read(workoutBuilderProvider.notifier).updateTitle(value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Add notes about this workout',
            ),
            maxLines: 3,
            onChanged: (value) {
              ref.read(workoutBuilderProvider.notifier).updateDescription(value);
            },
          ),
          const SizedBox(height: 32),
          
          // Add exercise button
          OutlinedButton.icon(
            onPressed: _addExercise,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Exercise'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.centerLeft,
            ),
          ),
          const SizedBox(height: 24),

          // Exercises list
          if (plan.exercises.isNotEmpty) ...[
            Text(
              'Exercises',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...plan.exercises.asMap().entries.map((entry) {
              final index = entry.key;
              final exercise = entry.value;
              return _ExerciseListItem(
                exercise: exercise,
                index: index,
                onRemove: () {
                  ref.read(workoutBuilderProvider.notifier).removeExercise(exercise);
                },
                onEdit: () async {
                  // For now, just allow removing and re-adding
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Remove and re-add exercise to edit')),
                  );
                  return null;
                },
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _ExerciseListItem extends StatelessWidget {
  const _ExerciseListItem({
    required this.exercise,
    required this.index,
    required this.onRemove,
    required this.onEdit,
  });

  final WorkoutExercise exercise;
  final int index;
  final VoidCallback onRemove;
  final Future<WorkoutExercise?> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${index + 1}'),
        ),
        title: Text(exercise.exerciseName),
        subtitle: Text(
          '${exercise.sets.length} sets × ${exercise.sets.first.reps ?? 0} reps • ${exercise.restSeconds}s rest',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onRemove,
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }
}

