import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../workout/domain/models.dart';
import 'package:go_router/go_router.dart';

class WorkoutCustomPage extends StatefulWidget {
  const WorkoutCustomPage({super.key});

  @override
  State<WorkoutCustomPage> createState() => _WorkoutCustomPageState();
}

class _WorkoutCustomPageState extends State<WorkoutCustomPage> {
  final List<SessionExercise> items = <SessionExercise>[];
  final TextEditingController titleCtrl = TextEditingController(text: 'Custom Session');
  WorkoutDifficulty difficulty = WorkoutDifficulty.easy; // retained but hidden from UI per request

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Workout')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            TextFormField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Session title'),
            ),
            // Difficulty selection removed for custom builder per UX request
            const SizedBox(height: 16),
            Text('Exercises', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('No exercises yet'),
                  subtitle: const Text('Tap "Add exercise" to include your first move.'),
                ),
              ),
            for (int i = 0; i < items.length; i++)
              _ExerciseTile(
                index: i,
                data: items[i],
                onRemove: () => setState(() => items.removeAt(i)),
                onEdit: () => _onEditExercise(i),
                onMoveUp: i == 0
                    ? null
                    : () => setState(() {
                          final tmp = items[i - 1];
                          items[i - 1] = items[i];
                          items[i] = tmp;
                        }),
                onMoveDown: i == items.length - 1
                    ? null
                    : () => setState(() {
                          final tmp = items[i + 1];
                          items[i + 1] = items[i];
                          items[i] = tmp;
                        }),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _onAddExercise,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add exercise'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: items.isEmpty
                  ? null
                  : () {
                      final session = WorkoutSession(
                        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                        title: titleCtrl.text.trim().isEmpty ? 'Custom Session' : titleCtrl.text.trim(),
                        estimatedDuration: _estimateDurationForExercises(items),
                        difficulty: difficulty,
                        exercises: List<SessionExercise>.from(items),
                      );
                      final plan = WorkoutPlan(
                        id: 'plan_custom_${DateTime.now().millisecondsSinceEpoch}',
                        name: 'Custom Plan',
                        goal: WorkoutGoal.generalFitness,
                        weeks: 1,
                        sessions: <WorkoutSession>[session],
                      );
                      context.push('/home/workout/preview', extra: plan);
                    },
              child: const Text('Preview'),
            ),
          ],
        ),
      ),
    );
  }

  void _onAddExercise() async {
    final SessionExercise? added = await showModalBottomSheet<SessionExercise>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _ExercisePicker(difficulty: difficulty);
      },
    );
    if (added != null) setState(() => items.add(added));
  }

  void _onEditExercise(int index) async {
    final existing = items[index];
    final SessionExercise? edited = await showModalBottomSheet<SessionExercise>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ExercisePicker(
        difficulty: difficulty,
        initialName: existing.exercise.name,
        initialSets: existing.prescription.sets,
        initialRepsMin: existing.prescription.repsMin,
        initialRepsMax: existing.prescription.repsMax,
        initialRest: existing.prescription.restSeconds,
        initialWeightKg: existing.prescription.targetWeightKg,
      ),
    );
    if (edited != null) setState(() => items[index] = edited);
  }

  Duration _estimateDurationForExercises(List<SessionExercise> list) {
    int totalSeconds = 0;
    for (final se in list) {
      totalSeconds += se.prescription.sets * se.prescription.restSeconds;
    }
    return Duration(seconds: totalSeconds);
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.index,
    required this.data,
    required this.onRemove,
    required this.onEdit,
    this.onMoveUp,
    this.onMoveDown,
  });
  final int index;
  final SessionExercise data;
  final VoidCallback onRemove;
  final VoidCallback onEdit;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('${index + 1}')),
        title: Text(data.exercise.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${data.prescription.sets} x ${data.prescription.repsMin}-${data.prescription.repsMax}  •  Rest ${data.prescription.restSeconds}s' +
                (data.prescription.targetWeightKg != null
                    ? '  •  ${(data.prescription.targetWeightKg!).toStringAsFixed((data.prescription.targetWeightKg! % 1 == 0) ? 0 : 1)} kg'
                    : '')),
        onTap: onEdit,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
            IconButton(onPressed: onMoveUp, icon: const Icon(Icons.arrow_upward_rounded)),
            IconButton(onPressed: onMoveDown, icon: const Icon(Icons.arrow_downward_rounded)),
            IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline_rounded)),
          ],
        ),
      ),
    );
  }
}

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker({
    required this.difficulty,
    this.initialName,
    this.initialSets,
    this.initialRepsMin,
    this.initialRepsMax,
    this.initialRest,
    this.initialWeightKg,
  });
  final WorkoutDifficulty difficulty;
  final String? initialName;
  final int? initialSets;
  final int? initialRepsMin;
  final int? initialRepsMax;
  final int? initialRest;
  final double? initialWeightKg;

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  late final TextEditingController nameCtrl;
  int sets = 3;
  int repsMin = 8;
  int repsMax = 12;
  int rest = 90;
  double? weightKg;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.initialName ?? '');
    switch (widget.difficulty) {
      case WorkoutDifficulty.easy:
        sets = 2;
        repsMin = 8;
        repsMax = 12;
        rest = 60;
        break;
      case WorkoutDifficulty.medium:
        sets = 3;
        repsMin = 8;
        repsMax = 12;
        rest = 90;
        break;
      case WorkoutDifficulty.hard:
        sets = 4;
        repsMin = 6;
        repsMax = 10;
        rest = 120;
        break;
    }
    if (widget.initialSets != null) sets = widget.initialSets!;
    if (widget.initialRepsMin != null) repsMin = widget.initialRepsMin!;
    if (widget.initialRepsMax != null) repsMax = widget.initialRepsMax!;
    if (widget.initialRest != null) rest = widget.initialRest!;
    if (widget.initialWeightKg != null) weightKg = widget.initialWeightKg!;
    nameCtrl.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 4),
              Text(widget.initialName == null ? 'Add exercise' : 'Edit exercise', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Exercise name'),
          const SizedBox(height: 8),
          TextFormField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'e.g., Push-Up, Squat, Plank',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: sets.toString(),
                  decoration: const InputDecoration(labelText: 'Sets'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => sets = (int.tryParse(v) ?? sets).clamp(1, 10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: repsMin.toString(),
                  decoration: const InputDecoration(labelText: 'Reps min'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    repsMin = (int.tryParse(v) ?? repsMin).clamp(1, 100);
                    if (repsMax < repsMin) repsMax = repsMin;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: repsMax.toString(),
                  decoration: const InputDecoration(labelText: 'Reps max'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    repsMax = (int.tryParse(v) ?? repsMax).clamp(1, 100);
                    if (repsMax < repsMin) repsMin = repsMax;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: rest.toString(),
                  decoration: const InputDecoration(labelText: 'Rest (s)'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => rest = (int.tryParse(v) ?? rest).clamp(10, 600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: weightKg == null
                      ? ''
                      : weightKg!.toStringAsFixed(weightKg! % 1 == 0 ? 0 : 1),
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    final parsed = double.tryParse(v.trim());
                    weightKg = (parsed == null || parsed <= 0) ? null : parsed.clamp(0, 1000);
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: nameCtrl.text.trim().isEmpty
                      ? null
                      : () {
                          final String name = nameCtrl.text.trim();
                          final result = SessionExercise(
                            exercise: Exercise(
                              id: 'local_${DateTime.now().millisecondsSinceEpoch}',
                              name: name,
                              primaryMuscles: const <String>[],
                              equipment: EquipmentType.none,
                            ),
                            prescription: SetPrescription(
                              sets: sets,
                              repsMin: repsMin,
                              repsMax: repsMax,
                              restSeconds: rest,
                              targetWeightKg: weightKg,
                            ),
                          );
                          Navigator.of(context).pop(result);
                        },
                  child: Text(widget.initialName == null ? 'Add' : 'Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


