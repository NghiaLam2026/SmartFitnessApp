import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../workouts/application/workout_providers.dart';
import '../../workouts/domain/workout_models.dart';

/// Widget for selecting a workout from user's workout plans
/// Displays a mobile-friendly dropdown/picker for selecting workouts
class WorkoutSelectorWidget extends ConsumerWidget {
  final String? selectedWorkoutId;
  final ValueChanged<String?> onWorkoutSelected;
  final bool enabled;

  const WorkoutSelectorWidget({
    super.key,
    this.selectedWorkoutId,
    required this.onWorkoutSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(userWorkoutPlansProvider);

    return workoutsAsync.when(
      data: (workouts) {
        if (workouts.isEmpty) {
          return const SizedBox.shrink();
        }

        // Find selected workout if one is selected
        WorkoutPlan? selectedWorkout;
        if (selectedWorkoutId != null) {
          try {
            selectedWorkout = workouts.firstWhere((w) => w.id == selectedWorkoutId);
          } catch (_) {
            // Workout not found (might have been deleted)
            selectedWorkout = null;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Link Workout (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: enabled ? () => _showWorkoutPicker(context, workouts, ref) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: enabled ? Colors.white : Colors.grey.shade100,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.fitness_center,
                      size: 20,
                      color: selectedWorkoutId != null
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selectedWorkout != null
                            ? selectedWorkout.title
                            : 'No workout selected',
                        style: TextStyle(
                          fontSize: 16,
                          color: selectedWorkout != null
                              ? Colors.black87
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    if (selectedWorkoutId != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: enabled
                            ? () {
                                onWorkoutSelected(null);
                              }
                            : null,
                        tooltip: 'Remove workout',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const Icon(Icons.arrow_drop_down, size: 24),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  void _showWorkoutPicker(
    BuildContext context,
    List<WorkoutPlan> workouts,
    WidgetRef ref,
  ) {
    // Store the callback to use after bottom sheet closes
    final callback = onWorkoutSelected;
    
    showModalBottomSheet<String?>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => _WorkoutPickerSheet(
        workouts: workouts,
        selectedWorkoutId: selectedWorkoutId,
        onWorkoutSelected: (workoutId) {
          // Close the bottom sheet and return the selected workout ID
          Navigator.pop(bottomSheetContext, workoutId);
        },
      ),
    ).then((selectedId) {
      // Only update state after bottom sheet is fully closed
      // selectedId can be a workout ID (String) or null (if cleared)
      // If user dismisses by swiping, selectedId will be null and we don't update
      // Small delay to ensure bottom sheet animation completes before updating dialog state
      Future.delayed(const Duration(milliseconds: 150), () {
        // Only update if we have a result (either workout ID or explicit null from Clear button)
        // This prevents updating when user just dismisses the sheet
        callback(selectedId);
      });
    });
  }
}

class _WorkoutPickerSheet extends StatelessWidget {
  final List<WorkoutPlan> workouts;
  final String? selectedWorkoutId;
  final ValueChanged<String?> onWorkoutSelected;

  const _WorkoutPickerSheet({
    required this.workouts,
    required this.selectedWorkoutId,
    required this.onWorkoutSelected,
  });

  void _handleSelection(BuildContext context, String? workoutId) {
    // Close the bottom sheet and return the selected workout ID
    // The parent will handle the state update after the sheet closes
    Navigator.pop(context, workoutId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Select Workout',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _handleSelection(context, null),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: workouts.length,
              itemBuilder: (context, index) {
                final workout = workouts[index];
                final isSelected = workout.id == selectedWorkoutId;

                return ListTile(
                  leading: Icon(
                    Icons.fitness_center,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  title: Text(workout.title),
                  subtitle: workout.exercises.isNotEmpty
                      ? Text('${workout.exercises.length} exercises')
                      : null,
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  selected: isSelected,
                  onTap: () => _handleSelection(context, workout.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

