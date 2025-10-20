import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../workout/domain/models.dart';
import 'package:go_router/go_router.dart';
import '../infrastructure/workout_repository.dart';

class WorkoutPreviewPage extends ConsumerWidget {
  const WorkoutPreviewPage({super.key, required this.plan});
  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final totalDuration = _estimatePlanDuration(plan);
    return Scaffold(
      appBar: AppBar(title: const Text('Plan Preview')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Text(plan.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${plan.sessions.length} sessions • ${plan.weeks} weeks • ~${totalDuration.inMinutes} min'),
            const SizedBox(height: 16),
            for (final s in plan.sessions) _SessionCard(session: s),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                final repo = ref.read(workoutRepositoryProvider);
                try {
                  await repo.savePlan(plan);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to your plan')));
                  context.go('/home/plan');
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save plan')));
                  }
                }
              },
              child: const Text('Add to My Plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = _estimateSessionDuration(session);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('~${duration.inMinutes} min • ${_label(session.difficulty)}'),
            const SizedBox(height: 8),
            for (final e in session.exercises)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.fitness_center_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.exercise.name)),
                    Text('${e.prescription.sets} x ${e.prescription.repsMin}-${e.prescription.repsMax}'),
                    if (e.prescription.targetWeightKg != null) ...[
                      const SizedBox(width: 8),
                      Text('${e.prescription.targetWeightKg!.toStringAsFixed((e.prescription.targetWeightKg! % 1 == 0) ? 0 : 1)} kg'),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _label(WorkoutDifficulty d) {
    switch (d) {
      case WorkoutDifficulty.easy:
        return 'Easy';
      case WorkoutDifficulty.medium:
        return 'Medium';
      case WorkoutDifficulty.hard:
        return 'Hard';
    }
  }

  static Duration _estimateSessionDuration(WorkoutSession s) {
    int seconds = 0;
    for (final se in s.exercises) {
      seconds += se.prescription.sets * se.prescription.restSeconds;
    }
    return Duration(seconds: seconds);
  }
}

Duration _estimatePlanDuration(WorkoutPlan plan) {
  int seconds = 0;
  for (final s in plan.sessions) {
    seconds += _SessionCard._estimateSessionDuration(s).inSeconds;
  }
  return Duration(seconds: seconds);
}


