import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/supabase/supabase_client.dart';
import '../application/workout_providers.dart';
import '../domain/workout_models.dart';
import '../../exercises/domain/exercise_models.dart';
import '../../exercises/infrastructure/exercises_repository.dart';

final uuid = Uuid();

// Constants for weight conversion
const double _lbsToKg = 0.453592;
const double _kgToLbs = 1 / _lbsToKg;

class CreateWorkoutPage extends ConsumerStatefulWidget {
  final String? workoutId; // If provided, edit mode; otherwise create mode
  
  const CreateWorkoutPage({
    super.key,
    this.workoutId,
  });

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
      if (widget.workoutId != null) {
        // Edit mode: load existing workout
        _loadWorkoutForEditing();
      } else {
        // Create mode: initialize empty builder
      ref.read(workoutBuilderProvider.notifier).initializeBuilder();
      }
    });
  }

  Future<void> _loadWorkoutForEditing() async {
    if (widget.workoutId == null) return;
    
    try {
      final repository = ref.read(workoutRepositoryProvider);
      final workoutPlan = await repository.fetchWorkoutPlanById(widget.workoutId!);
      
      if (workoutPlan != null && mounted) {
        final builder = ref.read(workoutBuilderProvider.notifier);
        // Load the workout into the builder
        builder.loadWorkout(workoutPlan);
        
        // Update controllers with loaded data
        _titleController.text = workoutPlan.title;
        _descriptionController.text = workoutPlan.description ?? '';
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout not found')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading workout: $e')),
        );
        context.pop();
      }
    }
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
      
      final isEditing = widget.workoutId != null;
      
      if (isEditing) {
        // Update existing workout
        final updatedPlan = WorkoutPlan(
          id: widget.workoutId!,
          title: plan.title,
          description: plan.description,
          userId: user?.id ?? '',
          createdAt: plan.createdAt,
          updatedAt: DateTime.now(),
          isAIGenerated: plan.isAIGenerated,
          exercises: plan.exercises,
        );
        
        await repository.updateWorkoutPlan(updatedPlan);
        
        // Invalidate both the individual plan and the list
        ref.invalidate(workoutPlanProvider(widget.workoutId!));
        ref.invalidate(userWorkoutPlansProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Workout updated successfully')),
          );
          context.pop();
        }
      } else {
        // Create new workout
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
        
        // Invalidate the provider to refresh the workout list
        ref.invalidate(userWorkoutPlansProvider);

      if (mounted) {
        context.pop();
        }
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
    return showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ExerciseSelectionSheet(),
    );
  }

  Future<WorkoutExercise?> _editExercise(WorkoutExercise workoutExercise) async {
    // Pre-populate with current values
    final repsController = TextEditingController(
      text: workoutExercise.sets.isNotEmpty && workoutExercise.sets.first.reps != null
          ? workoutExercise.sets.first.reps.toString()
          : '12',
    );
    final setsController = TextEditingController(text: workoutExercise.sets.length.toString());
    final restController = TextEditingController(text: workoutExercise.restSeconds.toString());
    
    // Get weight - stored in kg, display in kg by default
    final currentWeight = workoutExercise.sets.isNotEmpty ? workoutExercise.sets.first.weight : null;
    final weightController = TextEditingController(
      text: currentWeight != null ? currentWeight.toStringAsFixed(currentWeight % 1 == 0 ? 0 : 1) : '',
    );
    
    // Declare weightUnit outside builder to persist across rebuilds
    String weightUnit = 'kg'; // Default to kg (since we store in kg)

    return showDialog<WorkoutExercise>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
          title: Text('Edit: ${workoutExercise.exerciseName}'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: repsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Reps per set',
                    hintText: 'Enter reps (e.g., 12)',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: setsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Number of sets',
                    hintText: 'Enter number of sets (e.g., 3)',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: restController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Rest (seconds)',
                    hintText: 'Enter rest time (e.g., 60)',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Weight',
                    hintText: 'e.g., 20',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SegmentedButton<String>(
                        style: SegmentedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          minimumSize: const Size(0, 36),
                        ),
                        segments: const [
                          ButtonSegment(
                            value: 'kg',
                            label: Text('kg', style: TextStyle(fontSize: 12)),
                          ),
                          ButtonSegment(
                            value: 'lbs',
                            label: Text('lbs', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                        selected: {weightUnit},
                        onSelectionChanged: (Set<String> selection) {
                          setState(() {
                            final newUnit = selection.first;
                            final oldUnit = weightUnit;
                            // Convert displayed weight when unit changes
                            if (weightController.text.isNotEmpty) {
                              final weightValue = double.tryParse(weightController.text.trim());
                              if (weightValue != null) {
                                if (oldUnit == 'kg' && newUnit == 'lbs') {
                                  // Convert kg to lbs
                                  final convertedValue = weightValue * _kgToLbs;
                                  weightController.text = convertedValue.toStringAsFixed(
                                    convertedValue % 1 == 0 ? 0 : 1,
                                  );
                                } else if (oldUnit == 'lbs' && newUnit == 'kg') {
                                  // Convert lbs to kg
                                  final convertedValue = weightValue * _lbsToKg;
                                  weightController.text = convertedValue.toStringAsFixed(
                                    convertedValue % 1 == 0 ? 0 : 1,
                                  );
                                }
                              }
                            }
                            weightUnit = newUnit;
                          });
                        },
                      ),
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 80,
                      minHeight: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
            FilledButton(
              onPressed: () {
                // Validate and parse inputs with proper bounds checking
                final repsText = repsController.text.trim();
                final setsText = setsController.text.trim();
                final restText = restController.text.trim();
                final weightText = weightController.text.trim();
                
                // Validate reps (must be positive integer)
                final reps = int.tryParse(repsText);
                if (reps == null || reps <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid number of reps (greater than 0)')),
                  );
                  return;
                }
                
                // Validate sets (must be at least 1)
                final sets = int.tryParse(setsText);
                if (sets == null || sets < 1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid number of sets (at least 1)')),
                  );
                  return;
                }
                
                // Validate rest time (must be positive)
                final rest = int.tryParse(restText);
                if (rest == null || rest < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid rest time (0 or greater)')),
                  );
                  return;
                }
                
                // Parse weight and convert to kg if needed
                double? weight;
                if (weightText.isNotEmpty) {
                  final weightValue = double.tryParse(weightText);
                  if (weightValue == null || weightValue < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid weight (0 or greater)')),
                    );
                    return;
                  }
                  if (weightValue > 0) {
                    // Convert lbs to kg if needed
                    weight = weightUnit == 'lbs' ? weightValue * _lbsToKg : weightValue;
                    // Round to 2 decimal places for precision
                    weight = double.parse(weight.toStringAsFixed(2));
                  }
                }

                final editedExercise = WorkoutExercise(
                  id: workoutExercise.id, // Keep the same ID
                  workoutPlanId: workoutExercise.workoutPlanId,
                  exerciseId: workoutExercise.exerciseId,
                  exerciseName: workoutExercise.exerciseName,
                  orderIndex: workoutExercise.orderIndex, // Keep the same order
                  sets: List.generate(sets, (_) => ExerciseSet(
                    id: '',
                    workoutExerciseId: '',
                    reps: reps,
                    weight: weight,
                  )),
                  restSeconds: rest,
                  notes: workoutExercise.notes, // Preserve notes if any
                );

                context.pop(editedExercise);
              },
              child: const Text('Save'),
            ),
          ],
        );
        },
      ),
    ).then((result) {
      // Dispose controllers after dialog is fully closed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        repsController.dispose();
        setsController.dispose();
        restController.dispose();
        weightController.dispose();
      });
      return result;
    });
  }

  Future<WorkoutExercise?> _configureExercise(Exercise exercise) async {
    final repsController = TextEditingController();
    final setsController = TextEditingController();
    final restController = TextEditingController();
    final weightController = TextEditingController();
    
    // Declare weightUnit outside builder to persist across rebuilds
    String weightUnit = 'kg'; // Default to kg

    return showDialog<WorkoutExercise>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
        title: Text('Configure: ${exercise.name}'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: repsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Reps per set',
                  hintText: 'e.g., 12',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: setsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of sets',
                  hintText: 'e.g., 3',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: restController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Rest (seconds)',
                  hintText: 'e.g., 60',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Weight',
                    hintText: 'e.g., 20',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SegmentedButton<String>(
                        style: SegmentedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          minimumSize: const Size(0, 36),
                        ),
                        segments: const [
                          ButtonSegment(
                            value: 'kg',
                            label: Text('kg', style: TextStyle(fontSize: 12)),
                          ),
                          ButtonSegment(
                            value: 'lbs',
                            label: Text('lbs', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                        selected: {weightUnit},
                        onSelectionChanged: (Set<String> selection) {
                          setState(() {
                            final newUnit = selection.first;
                            final oldUnit = weightUnit;
                            // Convert displayed weight when unit changes
                            if (weightController.text.isNotEmpty) {
                              final weightValue = double.tryParse(weightController.text.trim());
                              if (weightValue != null) {
                                if (oldUnit == 'kg' && newUnit == 'lbs') {
                                  // Convert kg to lbs
                                  final convertedValue = weightValue * _kgToLbs;
                                  weightController.text = convertedValue.toStringAsFixed(
                                    convertedValue % 1 == 0 ? 0 : 1,
                                  );
                                } else if (oldUnit == 'lbs' && newUnit == 'kg') {
                                  // Convert lbs to kg
                                  final convertedValue = weightValue * _lbsToKg;
                                  weightController.text = convertedValue.toStringAsFixed(
                                    convertedValue % 1 == 0 ? 0 : 1,
                                  );
                                }
                              }
                            }
                            weightUnit = newUnit;
                          });
                        },
                      ),
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 80,
                      minHeight: 36,
                    ),
                ),
              ),
            ],
          ),
        ),
          actions: <Widget>[
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
                // Validate and parse inputs with proper bounds checking
                final repsText = repsController.text.trim();
                final setsText = setsController.text.trim();
                final restText = restController.text.trim();
                final weightText = weightController.text.trim();
                
                // Validate reps (must be positive integer)
                final reps = int.tryParse(repsText);
                if (reps == null || reps <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid number of reps (greater than 0)')),
                  );
                  return;
                }
                
                // Validate sets (must be at least 1)
                final sets = int.tryParse(setsText);
                if (sets == null || sets < 1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid number of sets (at least 1)')),
                  );
                  return;
                }
                
                // Validate rest time (must be positive)
                final rest = int.tryParse(restText);
                if (rest == null || rest < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid rest time (0 or greater)')),
                  );
                  return;
                }
                
                // Parse weight and convert to kg if needed
                double? weight;
                if (weightText.isNotEmpty) {
                  final weightValue = double.tryParse(weightText);
                  if (weightValue == null || weightValue < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid weight (0 or greater)')),
                    );
                    return;
                  }
                  if (weightValue > 0) {
                    // Convert lbs to kg if needed
                    weight = weightUnit == 'lbs' ? weightValue * _lbsToKg : weightValue;
                    // Round to 2 decimal places for precision
                    weight = double.parse(weight.toStringAsFixed(2));
                  }
                }

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
                    weight: weight,
                )),
                restSeconds: rest,
              );

              context.pop(workoutExercise);
            },
            child: const Text('Add'),
          ),
        ],
        );
        },
      ),
    ).then((result) {
      // Dispose controllers after dialog is fully closed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        repsController.dispose();
        setsController.dispose();
        restController.dispose();
        weightController.dispose();
      });
      return result;
    });
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
    
    // Only update controllers if they don't match the plan (to avoid overwriting user input)
    if (_titleController.text != plan.title) {
    _titleController.text = plan.title;
    }
    if (_descriptionController.text != (plan.description ?? '')) {
    _descriptionController.text = plan.description ?? '';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workoutId != null ? 'Edit Workout' : 'Create Workout'),
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
                  // Capture the notifier before opening dialog to avoid ref issues
                  final notifier = ref.read(workoutBuilderProvider.notifier);
                  final edited = await _editExercise(exercise);
                  if (edited != null && mounted) {
                    // Delay state update until after dialog is fully closed to avoid build conflicts
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        notifier.updateExercise(edited);
                      }
                    });
                  }
                  return edited;
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
          [
            '${exercise.sets.length} sets × ${exercise.sets.first.reps ?? 0} reps',
            if (exercise.sets.first.weight != null && exercise.sets.first.weight! > 0)
              '${exercise.sets.first.weight!.toStringAsFixed(1)} kg',
            '${exercise.restSeconds}s rest',
          ].join(' • '),
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

class _ExerciseSelectionSheet extends ConsumerStatefulWidget {
  const _ExerciseSelectionSheet();

  @override
  ConsumerState<_ExerciseSelectionSheet> createState() => _ExerciseSelectionSheetState();
}

class _ExerciseSelectionSheetState extends ConsumerState<_ExerciseSelectionSheet> {
  final _searchController = TextEditingController();
  String? _searchQuery;
  String? _selectedMuscle;
  bool? _isPrevention;
  Future<List<Exercise>>? _exercisesFuture;
  bool _hasSearchText = false;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadExercises() {
    final exercisesRepo = SupabaseExercisesRepository();
    setState(() {
      _exercisesFuture = exercisesRepo.fetchExercises(
        search: _searchQuery,
        muscle: _selectedMuscle,
        isPrevention: _isPrevention,
        limit: 100,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
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
                color: theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select Exercise',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            // Search and filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search exercises...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _hasSearchText
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = null;
                                  _hasSearchText = false;
                                });
                                _loadExercises();
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _hasSearchText = value.trim().isNotEmpty;
                        _searchQuery = value.trim().isEmpty ? null : value.trim();
                      });
                      _loadExercises();
                    },
                  ),
                  const SizedBox(height: 12),
                  // Muscle filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          isSelected: _selectedMuscle == null && _isPrevention == null,
                          onTap: () {
                            setState(() {
                              _selectedMuscle = null;
                              _isPrevention = null;
                            });
                            _loadExercises();
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Chest',
                          isSelected: _selectedMuscle == 'chest',
                          onTap: () {
                            setState(() {
                              _selectedMuscle = 'chest';
                              _isPrevention = null;
                            });
                            _loadExercises();
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Back',
                          isSelected: _selectedMuscle == 'back',
                          onTap: () {
                            setState(() {
                              _selectedMuscle = 'back';
                              _isPrevention = null;
                            });
                            _loadExercises();
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Legs',
                          isSelected: _selectedMuscle == 'legs',
                          onTap: () {
                            setState(() {
                              _selectedMuscle = 'legs';
                              _isPrevention = null;
                            });
                            _loadExercises();
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Arms',
                          isSelected: _selectedMuscle == 'arms',
                          onTap: () {
                            setState(() {
                              _selectedMuscle = 'arms';
                              _isPrevention = null;
                            });
                            _loadExercises();
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Shoulders',
                          isSelected: _selectedMuscle == 'shoulders',
                          onTap: () {
                            setState(() {
                              _selectedMuscle = 'shoulders';
                              _isPrevention = null;
                            });
                            _loadExercises();
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Core',
                          isSelected: _selectedMuscle == 'core',
                          onTap: () {
                            setState(() {
                              _selectedMuscle = 'core';
                              _isPrevention = null;
                            });
                            _loadExercises();
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Prevention',
                          isSelected: _isPrevention == true,
                          onTap: () {
                            setState(() {
                              _isPrevention = true;
                              _selectedMuscle = null;
                            });
                            _loadExercises();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // Exercises list
            Expanded(
              child: FutureBuilder<List<Exercise>>(
                future: _exercisesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading exercises',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _loadExercises,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  final exercises = snapshot.data ?? [];
                  
                  if (exercises.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No exercises found',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery != null || _selectedMuscle != null
                                ? 'Try adjusting your search or filters'
                                : 'No exercises available',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: exercises.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final exercise = exercises[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              exercise.name.isNotEmpty
                                  ? exercise.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            exercise.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            exercise.muscle ?? '—',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).pop(exercise),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.onPrimaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

